import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

/// A failing write must drop the CSRF mutex before session wipe. The wipe's
/// device-unregister POST uses the same client. Holding the mutex across that
/// post deadlocks every later write.
void main() {
  const failFast = Timeout(Duration(seconds: 5));

  test(
    '401 on a write whose wipe cleanup issues a write does not hang',
    () async {
      final harness = await _Harness.open(fault: _Fault.unauthorized);
      addTearDown(harness.dispose);
      await harness.login();

      await expectLater(
        harness.work('w1'),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(harness.adapter.workCalls, 1);
      expect(harness.adapter.unregisterCalls, 1);
      expect(harness.layer.session.state, _expired);
      harness.adapter.fault = _Fault.none;
      await harness.work('w2');
      expect(harness.adapter.workCalls, 2);
    },
    timeout: failFast,
  );

  test(
    'a non-CSRF 419 on a write whose wipe cleanup issues a write does not hang',
    () async {
      final harness = await _Harness.open(fault: _Fault.pageExpired);
      addTearDown(harness.dispose);
      await harness.login();

      await expectLater(
        harness.work('w1'),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(harness.adapter.workCalls, 1);
      expect(harness.adapter.unregisterCalls, 1);
      expect(harness.layer.session.state, _expired);
      harness.adapter.fault = _Fault.none;
      await harness.work('w2');
      expect(harness.adapter.workCalls, 2);
    },
    timeout: failFast,
  );

  test(
    'a 401 from GET /api/auth/csrf wipes the session and does not hold the lock',
    () async {
      final harness = await _Harness.open(fault: _Fault.csrfUnauthorized);
      addTearDown(harness.dispose);
      await harness.login();

      await expectLater(
        harness.layer.client.get(ApiEndpoints.csrf),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(harness.cleanupFinished, isTrue);
      expect(harness.layer.session.state, _expired);
      expect(await harness.cookies.isEmpty(), isTrue);
      harness.adapter.fault = _Fault.none;
      await harness.work('after-csrf-401');
      expect(harness.adapter.workCalls, 1);
    },
    timeout: failFast,
  );

  test('a write timeout releases the lock and is not replayed', () async {
    final harness = await _Harness.open(fault: _Fault.timeout);
    addTearDown(harness.dispose);
    await harness.login();

    await expectLater(
        harness.work('slow'), throwsA(isA<TimeoutApiException>()));
    expect(harness.adapter.workCalls, 1);
    expect(harness.layer.session.state, isA<SessionAuthenticated>());

    harness.adapter.fault = _Fault.none;
    await harness.work('after-timeout');
    expect(harness.adapter.workCalls, 2);
  }, timeout: failFast);

  test('a write network error releases the lock and is not replayed', () async {
    final harness = await _Harness.open(fault: _Fault.offline);
    addTearDown(harness.dispose);
    await harness.login();

    await expectLater(harness.work('down'), throwsA(isA<NetworkException>()));
    expect(harness.adapter.workCalls, 1);
    expect(harness.layer.session.state, isA<SessionAuthenticated>());

    harness.adapter.fault = _Fault.none;
    await harness.work('after-offline');
    expect(harness.adapter.workCalls, 2);
  }, timeout: failFast);

  test('a write 5xx is not replayed and the next write can run', () async {
    final harness = await _Harness.open(fault: _Fault.server);
    addTearDown(harness.dispose);
    await harness.login();

    await expectLater(harness.work('boom'), throwsA(isA<ServerException>()));
    expect(harness.adapter.workCalls, 1);
    expect(harness.layer.session.state, isA<SessionAuthenticated>());

    harness.adapter.fault = _Fault.none;
    await harness.work('after-500');
    expect(harness.adapter.workCalls, 2);
  }, timeout: failFast);

  test('a 409 VERSION_CONFLICT is not replayed and the next write can run',
      () async {
    final harness = await _Harness.open(fault: _Fault.conflict);
    addTearDown(harness.dispose);
    await harness.login();

    await expectLater(
      harness.work('stale'),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    expect(harness.adapter.workCalls, 1);
    expect(harness.layer.session.state, isA<SessionAuthenticated>());

    harness.adapter.fault = _Fault.none;
    await harness.work('after-409');
    expect(harness.adapter.workCalls, 2);
  }, timeout: failFast);
}

final _expired = isA<SessionUnauthenticated>().having(
  (state) => state.reason,
  'reason',
  'session_expired',
);

enum _Fault {
  none,
  unauthorized,
  pageExpired,
  csrfUnauthorized,
  timeout,
  offline,
  server,
  conflict,
}

class _Harness {
  _Harness(this.layer, this.adapter, this.cookies);

  final ApiLayer layer;
  final _Adapter adapter;
  final CookieStore cookies;
  var cleanupFinished = false;

  static Future<_Harness> open({required _Fault fault}) async {
    final adapter = _Adapter()..fault = fault;
    final cookies = InMemoryCookieStore();
    late ApiLayer layer;
    late _Harness harness;
    layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://api.example.invalid',
        useFakeApi: false,
      ),
      cookieStore: cookies,
      httpClientAdapter: adapter,
      cleanups: [
        () async {
          try {
            await layer.client.post(
              '/api/mobile-push/devices',
              body: const {'unregister': true, 'requestId': 'unregister'},
            );
          } catch (_) {}
          harness.cleanupFinished = true;
        },
      ],
    );
    harness = _Harness(layer, adapter, cookies);
    return harness;
  }

  Future<void> login() {
    return layer.session.login(username: 'admin', password: 'x');
  }

  Future<void> work(String requestId) async {
    await layer.client.post('/api/work', body: {'requestId': requestId});
  }

  Future<void> dispose() => layer.dispose();
}

class _Adapter implements HttpClientAdapter {
  _Fault fault = _Fault.none;
  int workCalls = 0;
  int unregisterCalls = 0;
  int csrfCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.isEmpty ? options.path : options.uri.path;
    final unsafe = options.method.toUpperCase() != 'GET' &&
        options.method.toUpperCase() != 'HEAD';
    if (path == ApiEndpoints.login) {
      return _ok(
        {'user': _user, 'csrfToken': 't'},
        setCookie: ['${ApiConfig.sessionCookieName}=s; Path=/; HttpOnly'],
      );
    }
    if (path == ApiEndpoints.me) return _ok({'user': _user});
    if (path == ApiEndpoints.csrf) {
      csrfCalls++;
      if (fault == _Fault.csrfUnauthorized) {
        return _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
      }
      return _ok({'csrfToken': 't2'});
    }
    if (path == '/api/mobile-push/devices') {
      unregisterCalls++;
      return _ok(const <String, Object?>{});
    }
    if (unsafe && path == '/api/work') {
      workCalls++;
      switch (fault) {
        case _Fault.unauthorized:
          return _fail(401, 'AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا.');
        case _Fault.pageExpired:
          return _fail(419, 'PAGE_EXPIRED', 'يجب تسجيل الدخول أولًا.');
        case _Fault.server:
          return _fail(500, 'SERVER_ERROR', 'خطأ في الخادم، حاول لاحقاً');
        case _Fault.conflict:
          return _fail(409, 'VERSION_CONFLICT', 'تم تعديل السجل');
        case _Fault.timeout:
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        case _Fault.offline:
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'simulated-offline',
          );
        case _Fault.none:
        case _Fault.csrfUnauthorized:
          break;
      }
    }
    return _ok(const <String, Object?>{});
  }
}

const _user = {
  'id': 'u_1',
  'username': 'admin',
  'displayName': 'x',
  'role': 'admin',
  'permissions': <String>[],
  'mustChangePassword': false,
};

ResponseBody _ok(Object? data, {List<String>? setCookie}) =>
    ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );

ResponseBody _fail(int status, String code, String message) =>
    ResponseBody.fromString(
      jsonEncode({
        'ok': false,
        'error': {
          'code': code,
          'message': message,
          'correlationId': 'corr-$status',
        },
      }),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
