import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_models.dart';
import '../../data/models/profile_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_strategy.dart';
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
/// switch (doc 04 §2) stays valid and for a possible future mobile token scheme.
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
    } catch (_) {
      if (state is! SessionUnauthenticated) {
        await _wipe(reason: 'restore_failed');
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
    _permissions.applyFromServer(me.user.permissions, isAdmin: me.user.isAdmin);
    _emit(SessionAuthenticated(me.user));
  }

  /// Calls the REAL logout endpoint first (needs cookie + CSRF), then wipes locally
  /// even if the call failed.
  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Ignore: local wipe happens regardless.
    }
    await _wipe(reason: 'logout');
  }

  /// Called by AuthInterceptor on AUTH_REQUIRED / session expired.
  Future<void> forceLogout(String reason) => _wipe(reason: reason);

  Future<void> _wipe({required String reason}) async {
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
      _emit(SessionUnauthenticated(reason: reason));
    } finally {
      _loggingOut = false;
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
