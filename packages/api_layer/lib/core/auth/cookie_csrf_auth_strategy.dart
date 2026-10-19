import 'dart:async';

import 'package:dio/dio.dart';

import '../network/api_endpoints.dart';
import '../network/api_exception.dart';
import 'auth_strategy.dart';
import 'cookie_store.dart';

/// Default strategy matching the server session (per API contract):
/// - Session = HTTP cookie set by POST /api/auth/login (persisted in [CookieStore]).
/// - CSRF token is returned as `csrfToken` by POST /api/auth/login and by
///   GET /api/auth/csrf, and must be sent as `X-CSRF-Token` on every non-GET request.
/// - The CSRF token is kept IN MEMORY only; after an app restart it is refetched
///   from GET /api/auth/csrf (same as the web client's `resume`).
/// - No refresh flow: AUTH_REQUIRED -> forced logout.
/// - CSRF invalid -> refetch the token ONCE (single-flight) and replay the request once.
class CookieCsrfAuthStrategy implements AuthStrategy {
  CookieCsrfAuthStrategy(
      {required CookieStore cookieStore, required Dio bareDio})
      : _cookies = cookieStore,
        _bareDio = bareDio;

  final CookieStore _cookies;

  /// Dio WITHOUT interceptors, used only to fetch the CSRF token.
  final Dio _bareDio;

  String? _csrfToken;
  Completer<bool>? _csrfInFlight;

  @override
  String get name => 'cookie+csrf';

  bool _isUnsafe(String method) {
    final m = method.toUpperCase();
    return m != 'GET' && m != 'HEAD';
  }

  @override
  Future<void> attach(RequestOptions options,
      {required bool authenticated}) async {
    // A reused RequestOptions (401 replay, CSRF retry, re-login) must not keep a
    // previous bearer header. This strategy never sends Authorization.
    _removeHeader(options.headers, 'Authorization');

    // Cookies are attached to public calls too (login may rotate a pre-session cookie).
    final cookie = await _cookies.cookieHeader();
    if (cookie != null && cookie.isNotEmpty) {
      options.headers['Cookie'] = cookie;
    } else {
      _removeHeader(options.headers, 'Cookie');
    }

    if (_isUnsafe(options.method)) {
      if (_csrfToken == null && authenticated) await refetchCsrfSingleFlight();
      final token = _csrfToken;
      if (token != null && token.isNotEmpty) {
        options.headers['X-CSRF-Token'] = token;
      } else {
        _removeHeader(options.headers, 'X-CSRF-Token');
      }
    } else {
      _removeHeader(options.headers, 'X-CSRF-Token');
    }
  }

  static void _removeHeader(Map<String, dynamic> headers, String name) {
    // Dio's header map is case-insensitive. removeWhere throws on that map.
    headers.remove(name);
  }

  @override
  Future<void> capture(Response<dynamic> response) async {
    final setCookie = response.headers.map['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      await _cookies.saveFromSetCookie(setCookie);
    }
  }

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async {
    final token = loginData['csrfToken'];
    _csrfToken = token is String && token.isNotEmpty ? token : null;
    if (_csrfToken == null) await refetchCsrfSingleFlight();
  }

  @override
  Future<void> onSessionResumed() async {
    await refetchCsrfSingleFlight();
  }

  @override
  Future<bool> hasPersistedSession() async => !(await _cookies.isEmpty());

  @override
  Future<AuthErrorAction> handleAuthError(
      ApiException error, RequestOptions request,
      {required bool authenticated}) async {
    if (error is CsrfInvalidException) {
      if (request.extra['authRetried'] == true) {
        return AuthErrorAction.passThrough;
      }
      _csrfToken = null;
      return await refetchCsrfSingleFlight()
          ? AuthErrorAction.retryOnce
          : AuthErrorAction.passThrough;
    }
    if (error is SessionExpiredException && authenticated) {
      return AuthErrorAction.forceLogout;
    }
    return AuthErrorAction.passThrough;
  }

  /// GET /api/auth/csrf -> { ok: true, data: { csrfToken } }. Shared by concurrent callers.
  Future<bool> refetchCsrfSingleFlight() async {
    final existing = _csrfInFlight;
    if (existing != null) return existing.future;
    final completer = Completer<bool>();
    _csrfInFlight = completer;
    try {
      final cookie = await _cookies.cookieHeader();
      final res = await _bareDio.get<Object?>(
        ApiEndpoints.csrf,
        options: Options(headers: {if (cookie != null) 'Cookie': cookie}),
      );
      await capture(res);
      final body = res.data;
      final data = body is Map && body['ok'] == true && body['data'] is Map
          ? body['data'] as Map
          : const {};
      final token = data['csrfToken'];
      _csrfToken = token is String && token.isNotEmpty ? token : null;
      completer.complete(_csrfToken != null);
    } catch (_) {
      completer.complete(false);
    } finally {
      _csrfInFlight = null;
    }
    return completer.future;
  }

  @override
  Future<void> clear() async {
    _csrfToken = null;
    await _cookies.clear();
  }
}
