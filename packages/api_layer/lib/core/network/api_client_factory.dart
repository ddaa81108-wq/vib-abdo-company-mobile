import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../data/fake/fake_api_client.dart';
import '../auth/auth_strategy.dart';
import '../auth/bearer_token_auth_strategy.dart';
import '../auth/cookie_csrf_auth_strategy.dart';
import '../auth/cookie_store.dart';
import '../config/api_config.dart';
import '../session/token_storage.dart';
import 'api_exception.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'dio_api_client.dart';
import 'get_retry_interceptor.dart';
import 'logging_interceptor.dart';
import 'precise_json.dart';

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
      final fake = FakeApiClient(
        rateWireFormat: config.rateWireFormat,
        latency: fakeLatency ?? const Duration(milliseconds: 250),
      );
      // In-memory stand-ins when the app did not inject stores. Real mode
      // below still defaults to secure storage. No bearer token is written.
      final cookies = cookieStore ?? InMemoryCookieStore();
      final tokens = tokenStorage ?? InMemoryTokenStorage();
      final strategy = _FakeCookieStrategy(cookies: cookies, tokens: tokens, client: fake);
      final dio = Dio(DioApiClient.baseOptions(config));
      dio.httpClientAdapter = _FakeAdapter(fake);
      final auth = AuthInterceptor(strategy: strategy, onForcedLogout: onForcedLogout)
        ..retryDio = dio;
      dio.interceptors.add(auth);
      final gateway = DioApiClient(dio, rateWireFormat: config.rateWireFormat);
      // DioApiClient installs a background transformer. Fake mode stays
      // synchronous so a 401 is mapped on this isolate and no socket opens.
      dio.transformer = _SyncJsonTransformer();
      fake.bindGateway(gateway);
      // dio stays null on the stack: realtime must not start in fake mode.
      return ApiStack._(fake, strategy, null);
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

/// Cookie session for the fake server. Same [AuthStrategy] path as the real
/// client: attach the cookie, keep CSRF in memory, [clear] drops the jar,
/// the token store, and that CSRF token. No refresh call.
class _FakeCookieStrategy implements AuthStrategy {
  _FakeCookieStrategy({
    required CookieStore cookies,
    required TokenStorage tokens,
    required FakeApiClient client,
  })  : _cookies = cookies,
        _tokens = tokens,
        _client = client;

  final CookieStore _cookies;
  final TokenStorage _tokens;
  final FakeApiClient _client;
  String? _csrfToken;

  @override
  String get name => 'fake-cookie';

  @override
  Future<void> attach(RequestOptions options, {required bool authenticated}) async {
    options.headers.remove('Authorization');
    final cookie = await _cookies.cookieHeader();
    if (cookie != null && cookie.isNotEmpty) {
      options.headers['Cookie'] = cookie;
    } else {
      options.headers.remove('Cookie');
    }
    final method = options.method.toUpperCase();
    final unsafe = method != 'GET' && method != 'HEAD';
    final token = _csrfToken;
    if (unsafe && token != null && token.isNotEmpty) {
      options.headers['X-CSRF-Token'] = token;
    } else {
      options.headers.remove('X-CSRF-Token');
    }
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
  }

  @override
  Future<void> onSessionResumed() async {}

  @override
  Future<bool> hasPersistedSession() async => !(await _cookies.isEmpty());

  @override
  Future<AuthErrorAction> handleAuthError(
    ApiException error,
    RequestOptions request, {
    required bool authenticated,
  }) async {
    if (error is SessionExpiredException && authenticated) {
      return AuthErrorAction.forceLogout;
    }
    return AuthErrorAction.passThrough;
  }

  @override
  Future<void> clear() async {
    _csrfToken = null;
    _client.dropHeldCookie();
    await _cookies.clear();
    await _tokens.clear();
  }
}

/// Speaks HTTP to [FakeApiClient] on this isolate. No socket.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._fake);
  final FakeApiClient _fake;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = <String, String>{};
    options.headers.forEach((key, value) {
      if (value == null) return;
      headers[key] = value is List ? value.join(', ') : '$value';
    });
    final query = options.queryParameters.isEmpty
        ? null
        : Map<String, dynamic>.from(options.queryParameters);
    final result = await _fake.serveHttp(
      method: options.method,
      path: options.uri.path.isEmpty ? options.path : options.uri.path,
      data: options.data,
      query: query,
      headers: headers,
      authenticated: options.extra['skipAuth'] != true,
    );
    return ResponseBody.fromString(
      result.body,
      result.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-correlation-id': ['fake'],
        if (result.setCookie.isNotEmpty) 'set-cookie': result.setCookie,
      },
    );
  }
}

class _SyncJsonTransformer extends Transformer {
  @override
  Future<String> transformRequest(RequestOptions options) async {
    final data = options.data;
    if (data == null) return '';
    if (data is String) return data;
    return jsonEncode(data);
  }

  @override
  Future<Object?> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    final text = await utf8.decoder.bind(responseBody.stream).join();
    if (text.isEmpty) return null;
    return PreciseJson.decode(text);
  }
}
