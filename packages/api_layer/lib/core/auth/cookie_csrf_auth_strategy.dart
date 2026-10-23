import 'dart:async';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../network/api_endpoints.dart';
import '../network/api_exception.dart';
import 'auth_strategy.dart';
import 'cookie_store.dart';

const _writeHeld = 'cookieCsrf.writeHeld';

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
///   takes one mutex, and so does that GET when it arrives through the main
///   client. It is not a second request: [adoptCsrfGet] runs the single-flight
///   refresh. The refresh waits until the mutex is free, then holds it.
///   A rejected write is replayed once.
/// - Other GET and HEAD requests are not queued.
/// - No refresh flow: AUTH_REQUIRED -> forced logout.
/// - A 419 that is not a CSRF error is session expiry (see [ErrorMapper]).
///   `docs/api/error-catalog.json` has no 419. `CSRF_REJECTED` is HTTP 403.
///   A 419 whose code or message contains CSRF still refreshes; any other 419
///   still wipes the session.
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
  Response<dynamic>? _flightResponse;
  Object? _flightError;

  /// 1 while a write or a CSRF refresh holds the mutex.
  ///
  /// The free path does not await. Awaiting an already-completed [Future]
  /// resumes in the zone that completed it. Widget tests create that future
  /// under fake async and then call `runAsync`, which does not pump fake
  /// async, so login would wait forever.
  int _heldWrites = 0;
  final List<Completer<void>> _writeWaiters = [];

  @override
  String get name => 'cookie+csrf';

  bool _isUnsafe(String method) {
    final m = method.toUpperCase();
    return m != 'GET' && m != 'HEAD';
  }

  bool _isAuthPath(String path, String endpoint) =>
      path == endpoint || path.endsWith(endpoint);

  bool _isCsrfGet(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    final path = options.uri.path.isEmpty ? options.path : options.uri.path;
    return _isAuthPath(path, ApiEndpoints.csrf) ||
        _isAuthPath(options.path, ApiEndpoints.csrf);
  }

  @override
  Future<Response<dynamic>?> adoptCsrfGet(RequestOptions options) async {
    if (!_isCsrfGet(options)) return null;
    // An in-flight refresh already holds the mutex. Joining it avoids a
    // second rotation. Otherwise wait for writes, then hold the mutex.
    if (_csrfInFlight != null) {
      await _fetchCsrfSingleFlight();
      return _responseOrThrow(options);
    }
    return _whenWritesIdle(() async {
      await _fetchCsrfSingleFlight();
      return _responseOrThrow(options);
    });
  }

  Response<dynamic> _responseOrThrow(RequestOptions options) {
    final response = _flightResponse;
    if (response != null && _flightError == null) {
      return Response<dynamic>(
        requestOptions: options,
        data: response.data,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        headers: response.headers,
      );
    }
    final error = _flightError;
    if (error is DioException) throw error;
    throw DioException(
      requestOptions: options,
      error: error,
      type: DioExceptionType.unknown,
    );
  }

  @override
  Future<void> acquireWrite(RequestOptions options) async {
    if (!_isUnsafe(options.method)) return;
    // Replay of the request that already holds the turn.
    if (options.extra[_writeHeld] == true) return;
    if (_heldWrites == 0) {
      _heldWrites = 1;
      options.extra[_writeHeld] = true;
      return;
    }
    final waiter = Completer<void>();
    _writeWaiters.add(waiter);
    await waiter.future;
    options.extra[_writeHeld] = true;
  }

  @override
  void releaseWrite(RequestOptions options) {
    if (options.extra[_writeHeld] != true) return;
    options.extra[_writeHeld] = false;
    _passTurn();
  }

  /// Hands the mutex to the next waiter after this call returns.
  ///
  /// [_heldWrites] stays 1 until that microtask, so a write that starts in
  /// between queues instead of running beside the handoff.
  void _passTurn() {
    scheduleMicrotask(() {
      if (_writeWaiters.isNotEmpty) {
        final next = _writeWaiters.removeAt(0);
        if (!next.isCompleted) next.complete();
        return;
      }
      _heldWrites = 0;
    });
  }

  /// Runs [action] only after every write that already holds the mutex has
  /// finished, and holds the mutex itself so a new write cannot start.
  Future<T> _whenWritesIdle<T>(Future<T> Function() action) async {
    if (_heldWrites != 0 || _writeWaiters.isNotEmpty) {
      final waiter = Completer<void>();
      _writeWaiters.add(waiter);
      await waiter.future;
    } else {
      _heldWrites = 1;
    }
    try {
      return await action();
    } finally {
      _passTurn();
    }
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
    _flightResponse = null;
    _flightError = null;
    final completer = Completer<bool>();
    _csrfInFlight = completer;
    unawaited(_finishCsrfFetch(completer));
    return completer.future;
  }

  Future<void> _finishCsrfFetch(Completer<bool> completer) async {
    try {
      final response = await _fetchCsrf();
      _flightResponse = response;
      final token = csrfTokenFromPayload(response.data);
      if (!completer.isCompleted) completer.complete(token != null);
    } catch (error) {
      // No token, cookie, or response text in this path.
      _flightError = error;
      if (!completer.isCompleted) completer.complete(false);
    } finally {
      if (identical(_csrfInFlight, completer)) _csrfInFlight = null;
    }
  }

  Future<Response<dynamic>> _fetchCsrf() async {
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
    return res;
  }

  @override
  Future<void> clear() async {
    _csrfToken = null;
    await _cookies.clear();
  }
}
