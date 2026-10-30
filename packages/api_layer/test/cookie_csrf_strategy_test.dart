import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/core/auth/cookie_csrf_auth_strategy.dart';
import 'package:flutter_api_layer/core/auth/cookie_store.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/core/network/auth_interceptor.dart';
import 'package:flutter_api_layer/core/network/dio_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local in-process adapter — no network, no contact with any real server.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<RequestOptions> seen = [];
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body, {List<String>? setCookie}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );

void main() {
  test(
      'cookie captured, CSRF attached, 403 CSRF_REJECTED refetched once, AUTH_REQUIRED forces logout',
      () async {
    var csrfCalls = 0;
    var postCalls = 0;
    String? forced;
    ResponseBody handle(RequestOptions o) {
      if (o.path == '/api/auth/login') {
        return _json(200, {
          'ok': true,
          'data': {
            'user': {'username': 'u'},
            'csrfToken': 't1'
          }
        }, setCookie: [
          'sid=abc; Path=/; HttpOnly; Secure'
        ]);
      }
      if (o.path == '/api/auth/csrf') {
        csrfCalls++;
        return _json(200, {
          'ok': true,
          'data': {'csrfToken': 't2'}
        });
      }
      if (o.path == '/api/x') {
        postCalls++;
        if (o.headers['X-CSRF-Token'] == 't1') {
          return _json(403, {
            'ok': false,
            'error': {
              'code': 'CSRF_REJECTED',
              'message': 'csrf',
              'correlationId': 'c1'
            }
          });
        }
        return _json(200, {
          'ok': true,
          'data': {
            'cookie': o.headers['Cookie'],
            'csrf': o.headers['X-CSRF-Token']
          }
        });
      }
      return _json(401, {
        'ok': false,
        'error': {
          'code': 'AUTH_REQUIRED',
          'message': 'login',
          'correlationId': 'c2'
        }
      });
    }

    final opts = BaseOptions(baseUrl: 'https://local.invalid');
    final bare = Dio(opts)..httpClientAdapter = _Adapter(handle);
    final dio = Dio(opts)..httpClientAdapter = _Adapter(handle);
    final strategy = CookieCsrfAuthStrategy(
        cookieStore: InMemoryCookieStore(), bareDio: bare);
    dio.interceptors.add(AuthInterceptor(
        strategy: strategy, onForcedLogout: (r) async => forced = r)
      ..retryDio = dio);
    final api = DioApiClient(dio);

    final login = await api.post('/api/auth/login',
        body: {'username': 'u', 'password': 'p'},
        options: const ApiRequestOptions(authenticated: false));
    await strategy.onLoginSucceeded(login.dataMap);

    final res = await api.post('/api/x', body: {'requestId': 'r1'});
    expect(res.dataMap['cookie'], 'sid=abc');
    expect(res.dataMap['csrf'], 't2');
    expect(csrfCalls, 1);
    expect(postCalls, 2);

    await expectLater(
        api.get('/api/me'), throwsA(isA<SessionExpiredException>()));
    expect(forced, 'session_expired');
  });

  test(
      'retry after 401, re-login, CSRF refresh, and logout keep only the current cookie and CSRF token',
      () async {
    var loginCount = 0;
    String? forced;
    final opts = BaseOptions(baseUrl: 'https://local.invalid');
    late final Dio dio;

    ResponseBody handle(RequestOptions o) {
      if (o.path == '/api/auth/login') {
        loginCount++;
        final sid = loginCount == 1 ? 'one' : 'two';
        final csrf = loginCount == 1 ? 't1' : 't3';
        return _json(
          200,
          {
            'ok': true,
            'data': {
              'user': {'username': 'u'},
              'csrfToken': csrf
            }
          },
          setCookie: ['sid=$sid; Path=/; HttpOnly; Secure'],
        );
      }
      if (o.path == '/api/auth/csrf') {
        final cookie = o.headers['Cookie'];
        if (cookie == null) {
          return _json(401, {
            'ok': false,
            'error': {
              'code': 'AUTH_REQUIRED',
              'message': 'login',
              'correlationId': 'c-csrf'
            }
          });
        }
        return _json(200, {
          'ok': true,
          'data': {'csrfToken': 't2'}
        });
      }
      if (o.path == '/api/work') {
        final csrf = o.headers['X-CSRF-Token'];
        if (csrf == 't1') {
          return _json(403, {
            'ok': false,
            'error': {
              'code': 'CSRF_REJECTED',
              'message': 'csrf',
              'correlationId': 'c1'
            }
          });
        }
        return _json(200, {
          'ok': true,
          'data': {
            'cookie': o.headers['Cookie'],
            'csrf': o.headers['X-CSRF-Token'],
            'authorization': o.headers['Authorization'],
          },
        });
      }
      return _json(401, {
        'ok': false,
        'error': {
          'code': 'AUTH_REQUIRED',
          'message': 'login',
          'correlationId': 'c2'
        }
      });
    }

    final adapter = _Adapter(handle);
    final bare = Dio(opts)..httpClientAdapter = adapter;
    dio = Dio(opts)..httpClientAdapter = adapter;
    final strategy = CookieCsrfAuthStrategy(
        cookieStore: InMemoryCookieStore(), bareDio: bare);
    dio.interceptors.add(
      AuthInterceptor(
        strategy: strategy,
        onForcedLogout: (reason) async {
          forced = reason;
          await strategy.clear();
        },
      )..retryDio = dio,
    );
    final api = DioApiClient(dio);
    const stale =
        ApiRequestOptions(headers: {'Authorization': 'Bearer stale-token'});

    final firstLogin = await api.post(
      '/api/auth/login',
      body: {'username': 'u', 'password': 'p'},
      options: const ApiRequestOptions(
          authenticated: false,
          headers: {'Authorization': 'Bearer stale-token'}),
    );
    await strategy.onLoginSucceeded(firstLogin.dataMap);

    final refreshed =
        await api.post('/api/work', body: {'requestId': 'r1'}, options: stale);
    expect(refreshed.dataMap['cookie'], 'sid=one');
    expect(refreshed.dataMap['csrf'], 't2');
    expect(refreshed.dataMap['authorization'], isNull);

    await expectLater(api.get('/api/me', options: stale),
        throwsA(isA<SessionExpiredException>()));
    expect(forced, 'session_expired');

    final secondLogin = await api.post(
      '/api/auth/login',
      body: {'username': 'u', 'password': 'p'},
      options: const ApiRequestOptions(
          authenticated: false,
          headers: {'Authorization': 'Bearer stale-token'}),
    );
    await strategy.onLoginSucceeded(secondLogin.dataMap);
    final afterRelogin =
        await api.post('/api/work', body: {'requestId': 'r2'}, options: stale);
    expect(afterRelogin.dataMap['cookie'], 'sid=two');
    expect(afterRelogin.dataMap['csrf'], 't3');
    expect(afterRelogin.dataMap['authorization'], isNull);

    await strategy.clear();
    final afterLogout =
        await api.post('/api/work', body: {'requestId': 'r3'}, options: stale);
    expect(afterLogout.dataMap['cookie'], isNull);
    expect(afterLogout.dataMap['csrf'], isNull);
    expect(afterLogout.dataMap['authorization'], isNull);

    for (final request in adapter.seen) {
      expect(request.headers['Authorization'], isNull, reason: request.path);
      expect(request.headers['authorization'], isNull, reason: request.path);
    }
    final credentialed = adapter.seen.where((request) =>
        request.headers['Cookie'] != null ||
        request.headers['X-CSRF-Token'] != null);
    expect(credentialed, isNotEmpty);
    expect(
      credentialed.every((request) =>
          request.headers['Cookie'] == 'sid=one' ||
          request.headers['Cookie'] == 'sid=two'),
      isTrue,
    );
  });
}
