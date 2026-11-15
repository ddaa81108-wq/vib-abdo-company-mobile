import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_models.dart';
import '../../data/models/profile_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_strategy.dart';
import '../network/api_exception.dart';
import '../permissions/permission_service.dart';

sealed class SessionState {
  const SessionState();
}

class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason});
  final String? reason; // 'logout' | 'session_expired' | 'restore_failed'
}

/// Login returned `MFA_REQUIRED`. The challenge cookie is not a session.
class SessionOtpRequired extends SessionState {
  const SessionOtpRequired(this.challenge);
  final LoginChallenge challenge;
}

/// Note: `profile.mustChangePassword` (server flag) -> router shows change-password screen.
class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.profile);
  final UserProfile profile;
}

/// Hook for clearing caches, local notifications, badge, downloaded files, push token, realtime.
typedef SessionCleanup = Future<void> Function();

/// Applies the window capture flag for a session generation.
///
/// [secure] runs before logout, expiry, and account switch so the previous
/// account cannot be captured while its widgets are still up. [applySession]
/// runs only after that generation is still the current one.
abstract interface class SessionCaptureGate {
  Future<void> secure({required int generation});

  Future<void> applySession({
    required int generation,
    required SessionState state,
  });
}

/// Cookie-session lifecycle for the real system:
///   login    POST /api/auth/login {username,password} -> {user, csrfToken}; then GET /api/me
///   restore  GET /api/me then GET /api/auth/csrf (same order as the web client's resume)
///   logout   POST /api/auth/logout (with X-CSRF-Token) -> wipe cookies + CSRF + caches
///   expiry   any AUTH_REQUIRED -> forceLogout (there is NO refresh flow)
class SessionManager {
  SessionManager({
    required AuthStrategy authStrategy,
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
    required PermissionService permissionService,
    SessionCaptureGate? captureGate,
    List<SessionCleanup> cleanups = const [],
  })  : _strategy = authStrategy,
        _auth = authRepository,
        _profile = profileRepository,
        _permissions = permissionService,
        _captureGate = captureGate,
        _cleanups = cleanups;

  final AuthStrategy _strategy;
  final AuthRepository _auth;
  final ProfileRepository _profile;
  final PermissionService _permissions;
  final SessionCaptureGate? _captureGate;
  final List<SessionCleanup> _cleanups;

  /// True from the start of [logout] until the wipe finishes.
  /// Section guards use this so a 401/403 during the logout request does
  /// not paint the permission-denied page while the window is still locked
  /// on the old session.
  bool get signingOut => _logoutRequested;

  /// Bumped before logout, expiry, and account switch. An in-flight profile
  /// read keeps the generation it started with and cannot publish after it.
  int _transitionEpoch = 0;

  /// Generation a request started on. A 401 from an older generation must
  /// not sign out the session that replaced it.
  int get transitionEpoch => _transitionEpoch;
  int _mfaTicket = 0;
  int _reloadSerial = 0;

  final _controller = StreamController<SessionState>.broadcast();
  final ValueNotifier<SessionState> _listenable =
      ValueNotifier<SessionState>(const SessionUnknown());
  bool _loggingOut = false;

  /// Set for the whole of [logout] so a 401 from that call, or from other
  /// requests finishing at the same time, still ends as reason `logout`.
  /// Cleared when a new [login] starts, so the login is not treated as
  /// mid-logout and a late wipe does not keep the signed-out gate up.
  bool _logoutRequested = false;
  Future<void>? _wipeInFlight;
  String? _wipeReason;

  /// Orders cookie clears against a new login writing its cookie. A wipe
  /// must not delete credentials a newer login has already committed, and
  /// a login must not write them underneath an in-flight clear.
  Future<void> _sessionWrite = Future<void>.value();

  /// Generation of the last login whose cookie was stored. A wipe captured
  /// at an older generation must not clear that cookie.
  int _loginCommittedEpoch = 0;

  Stream<SessionState> get states => _controller.stream;

  /// Always holds the latest state; late subscribers (e.g. go_router refreshListenable) get it immediately.
  ValueListenable<SessionState> get listenable => _listenable;
  SessionState get state => _listenable.value;
  UserProfile? get currentUser => switch (state) {
        SessionAuthenticated(:final profile) => profile,
        _ => null
      };

  /// App start: resume a persisted cookie session if any.
  Future<void> restore() async {
    await _secureNow(_transitionEpoch);
    if (!await _strategy.hasPersistedSession()) {
      await _strategy.clearMfaChallenge();
      await _publish(const SessionUnauthenticated());
      return;
    }
    try {
      await reloadProfileAndPermissions(); // AUTH_REQUIRED -> interceptor -> forceLogout
      if (state is! SessionAuthenticated) return;
      await _strategy.onSessionResumed(); // GET /api/auth/csrf
    } catch (error, stack) {
      if (state is! SessionUnauthenticated) {
        await _wipe(
          reason: 'restore_failed',
          capturedEpoch: _transitionEpoch,
        );
      }
      // 403 FORBIDDEN and PERMISSION_DENIED are the splash forbidden pane.
      // Every other restore failure stays a local wipe with no error screen.
      if (error is ForbiddenException &&
          (error.code == 'FORBIDDEN' || error.code == 'PERMISSION_DENIED')) {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }

  Future<void> login(
      {required String username, required String password}) async {
    // Supersede an in-flight logout. Otherwise the wipe still owns
    // [_loggingOut], reloadProfileAndPermissions drops this login, the
    // button returns with no error, and the new cookie stays on disk so
    // the next cold start is already signed in.
    _logoutRequested = false;
    _transitionEpoch++;
    _mfaTicket++;
    final switching =
        state is SessionAuthenticated || state is SessionOtpRequired;
    if (switching) await _secureNow(_transitionEpoch);
    final epoch = _transitionEpoch;
    try {
      final result = await _auth.login(username: username, password: password);
      // A newer login or logout won the race. Do not publish this one.
      if (epoch != _transitionEpoch) return;
      await _sessionWriteChain(() async {
        if (epoch != _transitionEpoch) return;
        await _strategy.onLoginSucceeded(result.raw);
        _loginCommittedEpoch = epoch;
        if (epoch != _transitionEpoch) return;
        await reloadProfileAndPermissions();
      });
    } on MfaRequiredException {
      if (epoch != _transitionEpoch) {
        if (state is! SessionOtpRequired) await _strategy.clearMfaChallenge();
        return;
      }
      await _publish(const SessionOtpRequired(LoginChallenge()));
    } catch (_) {
      if (switching &&
          epoch == _transitionEpoch &&
          state is SessionAuthenticated) {
        await _applyCapture(epoch);
      }
      rethrow;
    }
  }

  /// Completes a pending MFA challenge. `/api/me` runs only after success.
  Future<void> verifyMfa(String code) async {
    if (state is! SessionOtpRequired) {
      throw const MfaInvalidException(message: 'لا يوجد تحقق قائم');
    }
    final epoch = _transitionEpoch;
    final ticket = _mfaTicket;
    try {
      final result = await _auth.verifyMfa(code: code);
      final stale = ticket != _mfaTicket ||
          epoch != _transitionEpoch ||
          state is! SessionOtpRequired;
      if (stale) {
        if (state is! SessionAuthenticated) {
          await _dropUnadoptedMfaSession(result.raw);
        }
        return;
      }
      await _strategy.onLoginSucceeded(result.raw);
      if (ticket != _mfaTicket ||
          epoch != _transitionEpoch ||
          state is! SessionOtpRequired) {
        if (state is! SessionAuthenticated) {
          await _dropUnadoptedMfaSession(result.raw);
        }
        return;
      }
      await reloadProfileAndPermissions();
    } on MfaInvalidException {
      if (!await _strategy.hasMfaChallenge() && epoch == _transitionEpoch) {
        await _strategy.clearMfaChallenge();
        await _publish(const SessionUnauthenticated());
      }
      rethrow;
    }
  }

  /// Leaves the challenge. Does not create a session and does not call logout.
  Future<void> cancelMfa() async {
    if (state is! SessionOtpRequired) return;
    _transitionEpoch++;
    _mfaTicket++;
    await _secureNow(_transitionEpoch);
    await _strategy.clearMfaChallenge();
    await _publish(const SessionUnauthenticated());
  }

  /// A verify response arrived after cancel or logout. Revoke it and drop the cookie.
  Future<void> _dropUnadoptedMfaSession(Map<String, dynamic> raw) async {
    await _strategy.onLoginSucceeded(raw);
    try {
      await _auth.logout();
    } catch (_) {}
    await _strategy.clear();
  }

  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    await _auth.changePassword(
        currentPassword: currentPassword, newPassword: newPassword);
    await reloadProfileAndPermissions(); // server clears mustChangePassword
  }

  Future<void> reloadProfileAndPermissions() async {
    final epoch = _transitionEpoch;
    final serial = ++_reloadSerial;
    // The next profile may be a different role. Secure until it is applied.
    await _secureNow(epoch);
    try {
      final me = await _profile.fetchMe();
      if (!_reloadCurrent(serial, epoch)) return;
      _permissions.applyFromServer(
        me.user.permissions,
        role: me.user.role,
        sectionAccess: me.user.sectionAccess,
        fullAccess: me.user.fullAccess,
        isOwner: me.user.isOwner,
      );
      if (!_reloadCurrent(serial, epoch)) return;
      _emit(SessionAuthenticated(me.user));
      await _applyCapture(epoch);
    } catch (_) {
      if (_reloadCurrent(serial, epoch)) await _applyCapture(epoch);
      rethrow;
    }
  }

  /// Calls the REAL logout endpoint first (needs cookie + CSRF), then wipes locally
  /// even if the call failed. The reason is `logout`, not `session_expired`,
  /// so the login screen does not show the expiry notice.
  Future<void> logout() async {
    _logoutRequested = true;
    final epoch = ++_transitionEpoch;
    _mfaTicket++;
    _wipeReason = 'logout';
    await _secureNow(epoch);
    // The window is locked while this session is still the signed-in one.
    // The signed-out publication happens in the wipe, before permissions
    // are cleared, so the logout request itself still sees the old session.
    try {
      await _auth.logout();
    } catch (_) {
      // Ignore: local wipe happens regardless.
    }
    await _wipe(reason: 'logout', capturedEpoch: epoch);
  }

  /// Called by AuthInterceptor on AUTH_REQUIRED / session expired.
  ///
  /// Many requests can 401 together. They share one wipe. An explicit
  /// [logout] that overlaps those 401s keeps reason `logout`.
  Future<void> forceLogout(String reason) {
    // A login already in flight captured the previous generation. Bumping
    // here makes that result stale so it cannot publish after the expiry.
    final epoch = ++_transitionEpoch;
    return _wipe(
      reason: _logoutRequested ? 'logout' : reason,
      capturedEpoch: epoch,
    );
  }

  Future<void> _wipe({required String reason, required int capturedEpoch}) {
    if (reason == 'logout') _wipeReason = 'logout';
    _wipeReason ??= reason;
    final inFlight = _wipeInFlight;
    if (inFlight != null) return inFlight;
    if (state is SessionUnauthenticated && !_logoutRequested) {
      _wipeReason = null;
      return Future<void>.value();
    }
    final run = _performWipe(capturedEpoch);
    _wipeInFlight = run;
    return run;
  }

  Future<void> _performWipe(int epoch) async {
    if (_loggingOut) return;
    _loggingOut = true;
    // [epoch] is the generation that started this logout. A login that
    // commits a newer generation must keep its cookie and its session.
    try {
      await _sessionWriteChain(() async {
        if (_loginCommittedEpoch > epoch) return;
        await _secureNow(epoch);
        if (_loginCommittedEpoch > epoch) return;
        // Signed-out first, then the empty permission set. A frame during
        // the awaits below must already be unauthenticated so the router
        // sends /login and section guards do not announce a denial.
        final reason = _wipeReason ?? 'session_expired';
        _announceSignedOut(reason);
        _permissions.clear();
        await _strategy.clear(); // cookies + CSRF (or tokens)
        // A login committed while clear() was running. Its cookie is the
        // one that must survive; do not keep wiping.
        if (_loginCommittedEpoch > epoch || state is SessionAuthenticated) {
          return;
        }
        for (final c in _cleanups) {
          try {
            await c();
          } catch (_) {}
        }
        if (_loginCommittedEpoch > epoch || state is SessionAuthenticated) {
          return;
        }
        // A logout that started while this wipe was already running upgrades
        // session_expired to logout. Never downgrade an explicit logout, and
        // never replace a session a newer login has already published.
        _announceSignedOut(_wipeReason ?? reason, replaceAuthenticated: false);
        await _applyCapture(epoch);
      });
    } finally {
      _loggingOut = false;
      _wipeInFlight = null;
      _wipeReason = null;
      if (epoch == _transitionEpoch) _logoutRequested = false;
    }
  }

  /// Runs [body] after any in-flight cookie clear or login commit.
  Future<void> _sessionWriteChain(Future<void> Function() body) {
    final run = _sessionWrite.then((_) => body());
    _sessionWrite = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Publishes [reason] without dropping a logout that is already announced.
  /// A trailing upgrade must not replace a session a newer login published.
  void _announceSignedOut(
    String reason, {
    bool replaceAuthenticated = true,
  }) {
    final current = state;
    if (current is SessionAuthenticated && !replaceAuthenticated) return;
    if (current is SessionUnauthenticated) {
      if (current.reason == reason || current.reason == 'logout') return;
    }
    _emit(SessionUnauthenticated(reason: reason));
  }

  bool _reloadCurrent(int serial, int epoch) =>
      serial == _reloadSerial && epoch == _transitionEpoch;

  Future<void> _publish(SessionState next) async {
    final epoch = _transitionEpoch;
    _emit(next);
    await _applyCapture(epoch);
  }

  /// Sends the current session to the window again after the activity resumes.
  Future<void> reapplyCapture() => _applyCapture(_transitionEpoch);

  Future<void> _secureNow(int generation) async {
    final gate = _captureGate;
    if (gate == null) return;
    try {
      await gate.secure(generation: generation);
    } catch (_) {
      // The intent file and the activity pause still lock. The hold is last.
    }
  }

  Future<void> _applyCapture(int epoch) async {
    final gate = _captureGate;
    if (gate == null || epoch != _transitionEpoch) return;
    try {
      await gate.applySession(generation: epoch, state: state);
    } catch (_) {
      if (epoch != _transitionEpoch) return;
      await _secureNow(epoch);
    }
  }

  void _emit(SessionState s) {
    _listenable.value = s;
    _controller.add(s);
  }

  Future<void> dispose() async {
    _listenable.dispose();
    await _controller.close();
  }
}
