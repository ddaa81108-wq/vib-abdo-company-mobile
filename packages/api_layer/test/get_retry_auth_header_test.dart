import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/core/auth/auth_strategy.dart';
import 'package:flutter_api_layer/core/auth/bearer_token_auth_strategy.dart';
import 'package:flutter_api_layer/core/auth/cookie_csrf_auth_strategy.dart';
import 'package:flutter_api_layer/core/auth/cookie_store.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/auth_interceptor.dart';
import 'package:flutter_api_layer/core/network/dio_api_client.dart';
import 'package:flutter_api_layer/core/network/get_retry_interceptor.dart';
import 'package:flutter_api_layer/core/session/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A GET retried after 502/503 goes back through the full chain, so the auth
/// strategy re-attaches headers: no stale Authorization (cookie) / the CURRENT token (bearer).
/// Local adapter only — no network.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions o, int call) handler;
  final List<Map<String, dynamic>> seenHeaders = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seenHeaders.add(Map<String, dynamic>.from(o.headers));
    return handler(o, seenHeaders.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body, {Map<String, List<String>> extra = const {}}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...extra,
      },
    );

ResponseBody _fail(int status) => _json(
      status,
      {'ok': false, 'error': {'code': 'UPSTREAM', 'message': 'x', 'correlationId': 'c'}},
      extra: status == 503 ? {'retry-after': ['0']} : const {},
    );

ResponseBody _okEcho(RequestOptions o) => _json(200, {
      'ok': true,
      'data': {'authorization': o.headers['Authorization']},
    });

DioApiClient _client(AuthStrategy strategy, _Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://local.invalid'))..httpClientAdapter = adapter;
  dio.interceptors.addAll([
    AuthInterceptor(strategy: strategy, onForcedLogout: (_) async {})..retryDio = dio,
    GetRetryInterceptor(baseDelay: Duration.zero)..retryDio = dio,
  ]);
  return DioApiClient(dio);
}

const _stale = ApiRequestOptions(headers: {'Authorization': 'Bearer stale-token'});

void main() {
  for (final status in [502, 503]) {
    test('cookie strategy: GET retry after $status resends WITHOUT the stale Authorization', () async {
      final adapter = _Adapter((o, call) => call == 1 ? _fail(status) : _okEcho(o));
      final strategy = CookieCsrfAuthStrategy(
        cookieStore: InMemoryCookieStore(),
        bareDio: Dio(BaseOptions(baseUrl: 'https://local.invalid'))..httpClientAdapter = adapter,
      );
      final res = await _client(strategy, adapter).get('/api/me', options: _stale);

      expect(adapter.seenHeaders.length, 2, reason: 'one failure + one retry');
      for (final h in adapter.seenHeaders) {
        expect(h['Authorization'], isNull);
        expect(h['authorization'], isNull);
      }
      expect(res.dataMap['authorization'], isNull);
    });

    test('bearer strategy: GET retry after $status resends with the CURRENT token only', () async {
      final tokens = InMemoryTokenStorage();
      await tokens.saveTokens(accessToken: 'old', refreshToken: 'r');
      final adapter = _Adapter((o, call) {
        if (call == 1) {
          // Token rotates while the first attempt is failing.
          tokens.saveTokens(accessToken: 'new', refreshToken: 'r2');
          return _fail(status);
        }
        return _okEcho(o);
      });
      final res = await _client(BearerTokenAuthStrategy(tokenStorage: tokens), adapter).get('/api/me', options: _stale);

      expect(adapter.seenHeaders.length, 2);
      expect(adapter.seenHeaders[0]['Authorization'], 'Bearer old');
      expect(adapter.seenHeaders[1]['Authorization'], 'Bearer new');
      expect(adapter.seenHeaders.any((h) => '${h['Authorization']}'.contains('stale')), isFalse);
      expect(res.dataMap['authorization'], 'Bearer new');
    });
  }

  test('bearer strategy: after logout (tokens cleared) a retried GET carries no Authorization', () async {
    final tokens = InMemoryTokenStorage();
    await tokens.saveTokens(accessToken: 'old', refreshToken: 'r');
    final adapter = _Adapter((o, call) {
      if (call == 1) {
        tokens.clear();
        return _fail(502);
      }
      return _okEcho(o);
    });
    await _client(BearerTokenAuthStrategy(tokenStorage: tokens), adapter).get('/api/me', options: _stale);
    expect(adapter.seenHeaders[1]['Authorization'], isNull);
  });
}
