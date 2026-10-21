import 'package:dio/dio.dart';

import '../../data/fake/fake_api_client.dart';
import '../auth/auth_strategy.dart';
import '../auth/bearer_token_auth_strategy.dart';
import '../auth/cookie_csrf_auth_strategy.dart';
import '../auth/cookie_store.dart';
import '../config/api_config.dart';
import '../session/token_storage.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'dio_api_client.dart';
import 'get_retry_interceptor.dart';
import 'logging_interceptor.dart';

/// Wires the network stack. Interceptor order per API contract:
///   [AuthInterceptor, GetRetryInterceptor, SafeLoggingInterceptor]
class ApiStack {
  ApiStack._(this.client, this.strategy, this.dio);
  final ApiClient client;
  final AuthStrategy strategy;

  /// Main Dio (with interceptors). Used by SseRealtimeService for streaming. Null in fake mode.
  final Dio? dio;

  static ApiStack build({
    required ApiConfig config,
    required Future<void> Function(String reason) onForcedLogout,
    CookieStore? cookieStore,
    TokenStorage? tokenStorage,
    Duration? fakeLatency,
    HttpClientAdapter? httpClientAdapter,
  }) {
    if (config.useFakeApi) {
      return ApiStack._(
        FakeApiClient(
          rateWireFormat: config.rateWireFormat,
          latency: fakeLatency ?? const Duration(milliseconds: 250),
        ),
        // Fake mode has no cookie jar of its own. Stores passed by the app
        // are still wiped so a leftover bearer token cannot survive logout.
        _WipingStrategy(_FakeStrategy(), cookieStore, tokenStorage),
        null,
      );
    }

    final options = DioApiClient.baseOptions(config);
    final bareDio = Dio(options); // no interceptors: CSRF fetch only
    DioApiClient.usePreciseJson(bareDio);
    final dio = Dio(options);
    if (httpClientAdapter != null) {
      bareDio.httpClientAdapter = httpClientAdapter;
      dio.httpClientAdapter = httpClientAdapter;
    }
    // TLS pinning hook (optional): configure dio.httpClientAdapter with an
    // IOHttpClientAdapter + SecurityContext / badCertificateCallback using SPKI
    // pins supplied by the server owner, per API contract.

    // One pair of stores for the active strategy and for logout. Cookie mode
    // still clears the token store. Bearer mode still clears the cookie jar.
    final cookies = cookieStore ?? SecureCookieStore();
    final tokens = tokenStorage ?? SecureTokenStorage();
    final AuthStrategy strategy = _WipingStrategy(
      switch (config.authStrategy) {
        AuthStrategyKind.cookieCsrf =>
          CookieCsrfAuthStrategy(cookieStore: cookies, bareDio: bareDio),
        AuthStrategyKind.bearerToken =>
          BearerTokenAuthStrategy(tokenStorage: tokens),
      },
      cookies,
      tokens,
    );

    final auth =
        AuthInterceptor(strategy: strategy, onForcedLogout: onForcedLogout)
          ..retryDio = dio;
    final retry = GetRetryInterceptor()..retryDio = dio;
    dio.interceptors.addAll([
      auth,
      retry,
      SafeLoggingInterceptor(enabled: config.enableDebugLogging)
    ]);
    return ApiStack._(DioApiClient(dio, rateWireFormat: config.rateWireFormat),
        strategy, dio);
  }
}

/// Clears the active strategy (in-memory CSRF, or that strategy's own store)
/// and then both the cookie jar and the token store when this stack owns them.
class _WipingStrategy implements AuthStrategy {
  _WipingStrategy(this._inner, this._cookies, this._tokens);

  final AuthStrategy _inner;
  final CookieStore? _cookies;
  final TokenStorage? _tokens;

  @override
  String get name => _inner.name;

  @override
  Future<void> attach(RequestOptions options, {required bool authenticated}) =>
      _inner.attach(options, authenticated: authenticated);

  @override
  Future<void> capture(Response<dynamic> response) => _inner.capture(response);

  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) =>
      _inner.onLoginSucceeded(loginData);

  @override
  Future<void> onSessionResumed() => _inner.onSessionResumed();

  @override
  Future<bool> hasPersistedSession() => _inner.hasPersistedSession();

  @override
  Future<AuthErrorAction> handleAuthError(
          ApiException error, RequestOptions request,
          {required bool authenticated}) =>
      _inner.handleAuthError(error, request, authenticated: authenticated);

  @override
  Future<void> clear() async {
    await _inner.clear();
    await _cookies?.clear();
    await _tokens?.clear();
  }
}

/// No-op strategy for FakeApiClient (the fake keeps its own logged-in flag).
class _FakeStrategy implements AuthStrategy {
  bool _session = false;
  @override
  String get name => 'fake';
  @override
  Future<void> attach(RequestOptions options,
      {required bool authenticated}) async {}
  @override
  Future<void> capture(Response<dynamic> response) async {}
  @override
  Future<void> onLoginSucceeded(Map<String, dynamic> loginData) async =>
      _session = true;
  @override
  Future<void> onSessionResumed() async {}
  @override
  Future<bool> hasPersistedSession() async => _session;
  @override
  Future<AuthErrorAction> handleAuthError(error, RequestOptions request,
          {required bool authenticated}) async =>
      AuthErrorAction.passThrough;
  @override
  Future<void> clear() async => _session = false;
}
