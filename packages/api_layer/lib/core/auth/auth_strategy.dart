import 'package:dio/dio.dart';

import '../network/api_exception.dart';

/// What AuthInterceptor should do after an auth-related failure.
enum AuthErrorAction {
  /// Not an auth problem (or not recoverable) — propagate the error.
  passThrough,

  /// Strategy recovered (e.g. refetched CSRF token) — replay the request ONCE.
  retryOnce,

  /// Session is gone — SessionManager.forceLogout, then propagate.
  forceLogout,
}

/// Pluggable authentication. Default: [CookieCsrfAuthStrategy] (real system).
/// [BearerTokenAuthStrategy] is a stub kept behind the same interface until the
/// server owner answers whether a mobile token scheme will be added.
abstract interface class AuthStrategy {
  String get name;

  /// Attach credentials. [authenticated] is false for public endpoints (login, csrf).
  Future<void> attach(RequestOptions options, {required bool authenticated});

  /// Serializes POST, PUT, PATCH, and DELETE when a strategy must not overlap
  /// a CSRF refresh. GET and HEAD return immediately. A replay of the same
  /// [options] must not take a second turn.
  ///
  /// Only [CookieCsrfAuthStrategy] queues. Other strategies return immediately.
  Future<void> acquireWrite(RequestOptions options);

  /// Releases a turn taken by [acquireWrite]. Safe to call more than once.
  void releaseWrite(RequestOptions options);

  /// Inspect every response (success or error), e.g. persist Set-Cookie.
  Future<void> capture(Response<dynamic> response);

  /// Called by SessionManager with the unwrapped `data` of a successful login.
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData);

  /// Called after a persisted session was confirmed with GET /api/me.
  Future<void> onSessionResumed();

  /// Whether there is anything persisted that may represent a live session.
  Future<bool> hasPersistedSession();

  Future<AuthErrorAction> handleAuthError(
      ApiException error, RequestOptions request,
      {required bool authenticated});

  /// Wipe every credential (cookies, CSRF token, tokens).
  Future<void> clear();
}
