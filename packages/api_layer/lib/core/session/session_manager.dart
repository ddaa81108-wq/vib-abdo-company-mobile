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

/// Not produced by the current server (no OTP). Kept so the router's exhaustive
/// switch (per API contract) stays valid and for a possible future mobile token scheme.
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
    List<SessionCleanup> cleanups = const [],
  })  : _strategy = authStrategy,
        _auth = authRepository,
        _profile = profileRepository,
        _permissions = permissionService,
        _cleanups = cleanups;

  final AuthStrategy _strategy;
  final AuthRepository _auth;
  final ProfileRepository _profile;
  final PermissionService _permissions;
  final List<SessionCleanup> _cleanups;

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
    if (!await _strategy.hasPersistedSession()) {
      return _emit(const SessionUnauthenticated());
    }
    try {
      await reloadProfileAndPermissions(); // AUTH_REQUIRED -> interceptor -> forceLogout
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
    final result = await _auth.login(username: username, password: password);
    await _strategy.onLoginSucceeded(result.raw);
    await reloadProfileAndPermissions();
  }

  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    await _auth.changePassword(
        currentPassword: currentPassword, newPassword: newPassword);
    await reloadProfileAndPermissions(); // server clears mustChangePassword
  }

  Future<void> reloadProfileAndPermissions() async {
    final me = await _profile.fetchMe();
    _permissions.applyFromServer(
      me.user.permissions,
      role: me.user.role,
      sectionAccess: me.user.sectionAccess,
      fullAccess: me.user.fullAccess,
    );
    _emit(SessionAuthenticated(me.user));
  }

  /// Calls the REAL logout endpoint first (needs cookie + CSRF), then wipes locally
  /// even if the call failed. The reason is `logout`, not `session_expired`,
  /// so the login screen does not show the expiry notice.
  Future<void> logout() async {
    _logoutRequested = true;
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
    try {
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
    } finally {
      _loggingOut = false;
      _wipeInFlight = null;
      _wipeReason = null;
      _logoutRequested = false;
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
