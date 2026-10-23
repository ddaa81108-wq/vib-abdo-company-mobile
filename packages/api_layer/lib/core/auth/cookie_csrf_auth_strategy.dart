import 'dart:async';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../network/api_endpoints.dart';
import '../network/api_exception.dart';
import 'auth_strategy.dart';
import 'cookie_store.dart';

const _writeHeld = 'cookieCsrf.writeHeld';
const _writeGate = 'cookieCsrf.writeGate';

/// Reads `csrfToken` from a login or CSRF payload.
///
/// Accepts the raw envelope `{ok, data}` and the unwrapped `data` map.
/// Returns null when the field is missing or empty. The value is never logged.
String? csrfTokenFromPayload(Object? body) {
  if (body is! Map) return null;
  final nested = body['data'];
  final source = body['ok'] == true && nested is Map ? nested : body;
  final token = source['csrfToken'];
  if (token is String && token.isNotEmpty) return token;
  return null;
}

/// Default strategy matching the server session (per API contract):
/// - Session = HTTP cookie set by POST /api/auth/login (persisted in [CookieStore]).
///   The real name is [ApiConfig.sessionCookieName]. The jar keeps whatever
///   `Set-Cookie` sends; this strategy does not look up an older name.
/// - CSRF token is returned as `csrfToken` by POST /api/auth/login and by
///   GET /api/auth/csrf, and must be sent as `X-CSRF-Token` on every non-GET request.
/// - The CSRF token is kept IN MEMORY only; after an app restart it is refetched
///   from GET /api/auth/csrf (same as the web client's `resume`).
/// - GET /api/auth/csrf invalidates the previous token. Every POST/PUT/PATCH/DELETE
///   therefore takes one mutex. The refresh stays single-flight, runs only when
///   no other write holds the mutex, and a rejected write is replayed once.
/// - GET and HEAD are not queued.
/// - No refresh flow: AUTH_REQUIRED -> forced logout.
/// - A 419 that is not a CSRF error is session expiry (see [ErrorMapper]).
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
  Future<void> _writeTail = Future<void>.value();

  @override
  String get name => 'cookie+csrf';

  bool _isUnsafe(String method) {
    final m = method.toUpperCase();
    return m != 'GET' && m != 'HEAD';
  }

  bool _isAuthPath(String path, String endpoint) =>
      path == endpoint || path.endsWith(endpoint);

  @override
  Future<void> acquireWrite(RequestOptions options) async {
    if (!_isUnsafe(options.method)) return;
    // Replay of the request that already holds the turn.
    if (options.extra[_writeHeld] == true) return;
    final gate = Completer<void>();
    final previous = _writeTail;
    _writeTail = gate.future;
    options.extra[_writeGate] = gate;
    await previous;
    options.extra[_writeHeld] = true;
  }

  @override
  void releaseWrite(RequestOptions options) {
    if (options.extra[_writeHeld] != true) return;
    options.extra[_writeHeld] = false;
    final gate = options.extra.remove(_writeGate);
    if (gate is Completer<void> && !gate.isCompleted) gate.complete();
  }

  /// Runs [action] only after every write that already holds the mutex has
  /// finished, and holds the mutex itself so a new write cannot start.
  Future<T> _whenWritesIdle<T>(Future<T> Function() action) {
    final gate = Completer<void>();
    final previous = _writeTail;
    _writeTail = gate.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    });
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
      if (_csrfToken == null && authenticated) {
        await refetchCsrfSingleFlight(
          holdingWriteTurn: options.extra[_writeHeld] == true,
        );
      }
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
    _absorbCsrf(response);
  }

  /// Login and GET /api/auth/csrf both publish the token that writes must use.
  /// A refresh invalidates the previous token, so the in-memory value follows
  /// the latest success. Failures leave the previous value untouched.
  void _absorbCsrf(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) return;
    final path = response.requestOptions.uri.path;
    final raw = response.requestOptions.path;
    final login = _isAuthPath(path, ApiEndpoints.login) ||
        _isAuthPath(raw, ApiEndpoints.login);
    final csrf = _isAuthPath(path, ApiEndpoints.csrf) ||
        _isAuthPath(raw, ApiEndpoints.csrf);
    if (!login && !csrf) return;
    final token = csrfTokenFromPayload(response.data);
    if (token != null) _csrfToken = token;
  }

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async {
    final token = csrfTokenFromPayload(loginData);
    _csrfToken = token;
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
      final refreshed = await refetchCsrfSingleFlight(
        holdingWriteTurn: request.extra[_writeHeld] == true,
      );
      return refreshed
          ? AuthErrorAction.retryOnce
          : AuthErrorAction.passThrough;
    }
    if (error is SessionExpiredException && authenticated) {
      return AuthErrorAction.forceLogout;
    }
    return AuthErrorAction.passThrough;
  }

  /// GET /api/auth/csrf -> { ok: true, data: { csrfToken } }.
  ///
  /// Concurrent callers share one flight. A caller that does not already hold
  /// the write mutex waits until in-flight writes finish, then holds the mutex
  /// for the fetch so it cannot invalidate a token another write is sending.
  /// The server invalidates the previous token for this session.
  Future<bool> refetchCsrfSingleFlight({bool holdingWriteTurn = false}) {
    if (holdingWriteTurn) return _fetchCsrfSingleFlight();
    return _whenWritesIdle(_fetchCsrfSingleFlight);
  }

  Future<bool> _fetchCsrfSingleFlight() {
    final existing = _csrfInFlight;
    if (existing != null) return existing.future;
    final completer = Completer<bool>();
    _csrfInFlight = completer;
    unawaited(_finishCsrfFetch(completer));
    return completer.future;
  }

  Future<void> _finishCsrfFetch(Completer<bool> completer) async {
    try {
      final ok = await _fetchCsrf();
      if (!completer.isCompleted) completer.complete(ok);
    } catch (_) {
      // No token, cookie, or response text in this path.
      if (!completer.isCompleted) completer.complete(false);
    } finally {
      if (identical(_csrfInFlight, completer)) _csrfInFlight = null;
    }
  }

  Future<bool> _fetchCsrf() async {
    final cookie = await _cookies.cookieHeader();
    final res = await _bareDio.get<Object?>(
      ApiEndpoints.csrf,
      options: Options(
        headers: {
          ApiConfig.clientApiVersionHeader: ApiConfig.clientApiVersion,
          if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
        },
      ),
    );
    await capture(res);
    final token = csrfTokenFromPayload(res.data);
    _csrfToken = token;
    return token != null;
  }

  @override
  Future<void> clear() async {
    _csrfToken = null;
    await _cookies.clear();
  }
}
