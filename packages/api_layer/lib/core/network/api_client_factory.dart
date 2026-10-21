import 'package:dio/dio.dart';

import '../auth/auth_strategy.dart';
import '../auth/bearer_token_auth_strategy.dart';
import '../auth/cookie_csrf_auth_strategy.dart';
import '../auth/cookie_store.dart';
import '../config/api_config.dart';
import '../config/release_fake_api_guard.dart';
import '../session/token_storage.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'dio_api_client.dart';
import 'fake_client_builder.dart'
    if (dart.vm.product) 'fake_client_builder_release.dart';
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
  }) {
    if (config.useFakeApi) {
      rejectFakeApiInRelease(true);
      final fake = buildFakeStack(config: config, fakeLatency: fakeLatency);
      return ApiStack._(fake.client, fake.strategy, null);
    }

    final options = DioApiClient.baseOptions(config);
    final bareDio = Dio(options); // no interceptors: CSRF fetch only
    DioApiClient.usePreciseJson(bareDio);
    final dio = Dio(options);
    // TLS pinning hook (optional): configure dio.httpClientAdapter with an
    // IOHttpClientAdapter + SecurityContext / badCertificateCallback using SPKI
    // pins supplied by the server owner, per API contract.

    final AuthStrategy strategy = switch (config.authStrategy) {
      AuthStrategyKind.cookieCsrf => CookieCsrfAuthStrategy(
        cookieStore: cookieStore ?? SecureCookieStore(),
        bareDio: bareDio,
      ),
      AuthStrategyKind.bearerToken => BearerTokenAuthStrategy(
        tokenStorage: tokenStorage ?? SecureTokenStorage(),
      ),
    };

    final auth = AuthInterceptor(
      strategy: strategy,
      onForcedLogout: onForcedLogout,
    )..retryDio = dio;
    final retry = GetRetryInterceptor()..retryDio = dio;
    dio.interceptors.addAll([
      auth,
      retry,
      SafeLoggingInterceptor(enabled: config.enableDebugLogging),
    ]);
    return ApiStack._(
      DioApiClient(dio, rateWireFormat: config.rateWireFormat),
      strategy,
      dio,
    );
  }
}
