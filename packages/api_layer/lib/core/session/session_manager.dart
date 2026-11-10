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

  /// Bumped before logout, expiry, and account switch. An in-flight profile
  /// read keeps the generation it started with and cannot publish after it.
  int _transitionEpoch = 0;
  int _mfaTicket = 0;
  int _reloadSerial = 0;

  final _controller = StreamController<SessionState>.broadcast();
  final ValueNotifier<SessionState> _listenable =
      ValueNotifier<SessionState>(const SessionUnknown());
  bool _loggingOut = false;

  /// Set for the whole of [logout] so a 401 from that call, or from other
  /// requests finishing at the same time, still ends as reason `logout`.
  bool _logoutRequested = false;
  Future<void>? _wipeInFlight;
  String? _wipeReason;

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
        await _wipe(reason: 'restore_failed');
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
    final switching =
        state is SessionAuthenticated || state is SessionOtpRequired;
    if (switching) {
      _transitionEpoch++;
      _mfaTicket++;
      await _secureNow(_transitionEpoch);
    }
    final epoch = _transitionEpoch;
    try {
      final result = await _auth.login(username: username, password: password);
      // Logout or expiry won the race. Do not publish this login.
      if (epoch != _transitionEpoch) return;
      await _strategy.onLoginSucceeded(result.raw);
      if (epoch != _transitionEpoch) return;
      await reloadProfileAndPermissions();
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
    _transitionEpoch++;
    _mfaTicket++;
    await _secureNow(_transitionEpoch);
    try {
      await _auth.logout();
    } catch (_) {
      // Ignore: local wipe happens regardless.
    }
    await _wipe(reason: 'logout');
  }

  /// Called by AuthInterceptor on AUTH_REQUIRED / session expired.
  ///
  /// Many requests can 401 together. They share one wipe. An explicit
  /// [logout] that overlaps those 401s keeps reason `logout`.
  Future<void> forceLogout(String reason) =>
      _wipe(reason: _logoutRequested ? 'logout' : reason);

  Future<void> _wipe({required String reason}) {
    if (reason == 'logout') _wipeReason = 'logout';
    _wipeReason ??= reason;
    final inFlight = _wipeInFlight;
    if (inFlight != null) return inFlight;
    if (state is SessionUnauthenticated && !_logoutRequested) {
      _wipeReason = null;
      return Future<void>.value();
    }
    final run = _performWipe();
    _wipeInFlight = run;
    return run;
  }

  Future<void> _performWipe() async {
    if (_loggingOut) return;
    _loggingOut = true;
    _transitionEpoch++;
    final epoch = _transitionEpoch;
    try {
      await _secureNow(epoch);
      await _strategy.clear(); // cookies + CSRF (or tokens)
      _permissions.clear();
      for (final c in _cleanups) {
        try {
          await c();
        } catch (_) {}
      }
      // Read the reason after the awaits so a logout that started while this
      // wipe was already running can upgrade session_expired to logout.
      _emit(SessionUnauthenticated(reason: _wipeReason ?? 'session_expired'));
      await _applyCapture(epoch);
    } finally {
      _loggingOut = false;
      _wipeInFlight = null;
      _wipeReason = null;
      _logoutRequested = false;
    }
  }

  bool _reloadCurrent(int serial, int epoch) =>
      serial == _reloadSerial &&
      epoch == _transitionEpoch &&
      !_loggingOut &&
      _wipeInFlight == null;

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
