import 'package:dio/dio.dart';

import '../../data/fake/fake_api_client.dart';
import '../auth/auth_strategy.dart';
import '../auth/bearer_token_auth_strategy.dart';
import '../auth/cookie_csrf_auth_strategy.dart';
import '../auth/cookie_store.dart';
import '../config/api_config.dart';
import '../session/token_storage.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'dio_api_client.dart';
import 'get_retry_interceptor.dart';
import 'logging_interceptor.dart';

/// Wires the network stack. Interceptor order (doc 04 §6):
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
  }) {
    if (config.useFakeApi) {
      return ApiStack._(
        FakeApiClient(
          rateWireFormat: config.rateWireFormat,
          latency: fakeLatency ?? const Duration(milliseconds: 250),
        ),
        _FakeStrategy(),
        null,
      );
    }

    final options = DioApiClient.baseOptions(config);
    final bareDio = Dio(options); // no interceptors: CSRF fetch only
    DioApiClient.usePreciseJson(bareDio);
    final dio = Dio(options);
    // TLS pinning hook (optional): configure dio.httpClientAdapter with an
    // IOHttpClientAdapter + SecurityContext / badCertificateCallback using SPKI
    // pins supplied by the server owner (contract §13). 🔶

    final AuthStrategy strategy = switch (config.authStrategy) {
      AuthStrategyKind.cookieCsrf => CookieCsrfAuthStrategy(
          cookieStore: cookieStore ?? SecureCookieStore(), bareDio: bareDio),
      AuthStrategyKind.bearerToken => BearerTokenAuthStrategy(
          tokenStorage: tokenStorage ?? SecureTokenStorage()),
    };

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
