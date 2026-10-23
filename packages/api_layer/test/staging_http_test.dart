import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';
import 'package:flutter_api_layer/core/realtime/polling_realtime_service.dart';
import 'package:flutter_api_layer/core/realtime/sse_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-process adapter. No DNS and no socket.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions request) handler;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  int count(String path) => paths.where((item) => item == path).length;
}

ResponseBody _json(
  int status,
  Object body, {
  List<String>? setCookie,
}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );

ResponseBody _fail(int status, String code, String message) => _json(status, {
      'ok': false,
      'error': {
        'code': code,
        'message': message,
        'correlationId': 'corr-$status',
        'details': {'password': 'not-a-real-secret'},
      },
    });

ResponseBody _me() => _json(200, {
      'ok': true,
      'data': {
        'user': {
          'id': 'u1',
          'username': 'person',
          'displayName': 'شخص',
          'role': 'employee',
          'permissions': ['collections.read'],
          'mustChangePassword': false,
        },
      },
    });

void main() {
  const mapper = ErrorMapper();

  group('error mapper', () {
    DioException transport(DioExceptionType type) => DioException(
          requestOptions: RequestOptions(path: '/api/me'),
          type: type,
        );

    test('network and timeout', () {
      expect(
        mapper.map(transport(DioExceptionType.connectionError)),
        isA<NetworkException>(),
      );
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(mapper.map(transport(type)), isA<TimeoutApiException>());
      }
      final timedOut = mapper.fromResponse(408, '<html>timeout</html>');
      expect(timedOut, isA<TimeoutApiException>());
      expect(timedOut.code, 'TIMEOUT');
      expect(timedOut.message, isNot(contains('<')));
    });

    test('4xx and 5xx stay distinct, and HTML is not shown', () {
      expect(
        mapper.fromResponse(400, {
          'ok': false,
          'error': {'code': 'BAD', 'message': 'bad'},
        }),
        isA<BadRequestException>(),
      );
      expect(mapper.fromResponse(403, 'nope'), isA<ForbiddenException>());
      expect(mapper.fromResponse(404, 'missing'), isA<NotFoundException>());
      expect(mapper.fromResponse(409, 'conflict'), isA<ConflictException>());
      final server = mapper.fromResponse(503, '<html>down</html>');
      expect(server, isA<ServerException>());
      expect(server.code, 'SERVER_ERROR');
      expect(server.message, isNot(contains('<')));
      expect(server.message, 'خطأ في الخادم، حاول لاحقاً');
    });

    test('validation accepts a 422 list and a 400 fields map', () {
      final fromList = mapper.fromResponse(422, {
        'ok': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'البيانات المدخلة غير صحيحة',
          'details': [
            {'field': 'name', 'code': 'REQUIRED', 'message': 'الاسم مطلوب'},
          ],
        },
      });
      expect(fromList, isA<ValidationException>());
      expect(
        (fromList as ValidationException).fieldErrors.single.field,
        'name',
      );

      final fromFields = mapper.fromResponse(400, {
        'ok': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'تحقق',
          'details': {
            'fields': {'amount': 'المبلغ غير صالح'},
          },
        },
      });
      expect(fromFields, isA<ValidationException>());
      expect(
        (fromFields as ValidationException).fieldErrors.single.message,
        'المبلغ غير صالح',
      );
    });

    test('authenticated 401 and bare 419 expire the session', () {
      expect(
        mapper.fromResponse(401, {
          'ok': false,
          'error': {'code': 'AUTH_REQUIRED', 'message': 'login'},
        }),
        isA<SessionExpiredException>(),
      );
      final wrongCode = mapper.fromResponse(401, {
        'ok': false,
        'error': {'code': 'INVALID_CREDENTIALS', 'message': 'no'},
      });
      expect(wrongCode, isA<SessionExpiredException>());
      expect(wrongCode.code, 'INVALID_CREDENTIALS');
      final pageExpired = mapper.fromResponse(419, 'Page Expired');
      expect(pageExpired, isA<SessionExpiredException>());
      expect(pageExpired.code, 'PAGE_EXPIRED');
      expect(pageExpired.message, isNot(contains('Page Expired')));
      expect(pageExpired.message, 'يجب تسجيل الدخول أولًا.');
    });

    test('a public 401 is invalid credentials', () {
      final failed = mapper.fromResponse(
        401,
        {
          'ok': false,
          'error': {'code': 'AUTH_REQUIRED', 'message': 'رفض'},
        },
        null,
        false,
      );
      expect(failed, isA<InvalidCredentialsException>());
      expect(failed.message, 'رفض');
    });

    test('a 419 that names CSRF is a CSRF failure', () {
      final csrf = mapper.fromResponse(419, {
        'message': 'CSRF token mismatch.',
      });
      expect(csrf, isA<CsrfInvalidException>());
      expect(csrf.code, 'CSRF_INVALID');
    });
  });

  group('mocked staging client', () {
    const origin = 'https://staging.example.invalid';

    ApiLayer open(_Adapter adapter, InMemoryCookieStore cookies) {
      final layer = ApiLayer.create(
        config: const ApiConfig(baseUrl: origin, useFakeApi: false),
        cookieStore: cookies,
        httpClientAdapter: adapter,
      );
      addTearDown(layer.dispose);
      return layer;
    }

    test('401 clears the session once and is not retried', () async {
      final cookies = InMemoryCookieStore();
      await cookies.saveFromSetCookie(['sid=abc; Path=/; HttpOnly; Secure']);
      final adapter = _Adapter((_) => _fail(401, 'AUTH_REQUIRED', 'انتهت'));
      final layer = open(adapter, cookies);

      await expectLater(
        layer.client.get('/api/me'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(adapter.count('/api/me'), 1);
      expect(layer.session.state, isA<SessionUnauthenticated>());
      expect(
        (layer.session.state as SessionUnauthenticated).reason,
        'session_expired',
      );
      expect(await cookies.isEmpty(), isTrue);
    });

    test('419 clears the session once and is not retried', () async {
      final cookies = InMemoryCookieStore();
      await cookies.saveFromSetCookie(['sid=abc; Path=/; HttpOnly; Secure']);
      final adapter = _Adapter(
        (_) => _fail(419, 'PAGE_EXPIRED', 'انتهت الجلسة'),
      );
      final layer = open(adapter, cookies);

      await expectLater(
        layer.client.get('/api/me'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(adapter.count('/api/me'), 1);
      expect(
        (layer.session.state as SessionUnauthenticated).reason,
        'session_expired',
      );
      expect(await cookies.isEmpty(), isTrue);
    });

    test('login 401 does not clear a cookie or retry', () async {
      final cookies = InMemoryCookieStore();
      await cookies.saveFromSetCookie(['sid=abc; Path=/; HttpOnly; Secure']);
      final adapter = _Adapter(
        (_) => _fail(401, 'INVALID_CREDENTIALS', 'بيانات الدخول غير صحيحة'),
      );
      final layer = open(adapter, cookies);

      await expectLater(
        layer.client.post(
          '/api/auth/login',
          body: {'username': 'person', 'password': 'nope'},
          options: const ApiRequestOptions(authenticated: false),
        ),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(adapter.count('/api/auth/login'), 1);
      expect(layer.session.state, isA<SessionUnknown>());
      expect(await cookies.cookieHeader(), 'sid=abc');
    });

    test('a 419 that names CSRF is not refreshed or replayed', () async {
      final cookies = InMemoryCookieStore();
      final adapter = _Adapter((request) {
        if (request.path == '/api/auth/login') {
          return _json(
            200,
            {
              'ok': true,
              'data': {
                'user': {'username': 'person'},
                'csrfToken': 't1',
              },
            },
            setCookie: ['sid=abc; Path=/; HttpOnly; Secure'],
          );
        }
        if (request.path == '/api/me') return _me();
        if (request.path == '/api/auth/csrf') {
          return _json(200, {
            'ok': true,
            'data': {'csrfToken': 't2'},
          });
        }
        return _fail(419, 'CSRF_TOKEN_MISMATCH', 'CSRF token mismatch.');
      });
      final layer = open(adapter, cookies);
      await layer.session.login(username: 'person', password: 'secret');
      expect(layer.session.state, isA<SessionAuthenticated>());

      await expectLater(
        layer.client.post('/api/collections', body: {'requestId': 'r1'}),
        throwsA(
          isA<CsrfInvalidException>().having(
            isCsrfRejection,
            'replay',
            isFalse,
          ),
        ),
      );
      expect(adapter.count('/api/collections'), 1);
      expect(adapter.count('/api/auth/csrf'), 0);
      expect(layer.session.state, isA<SessionAuthenticated>());
      expect(await cookies.cookieHeader(), 'sid=abc');
    });

    test('a CSRF refresh that returns 401 does not replay or clear the session',
        () async {
      final cookies = InMemoryCookieStore();
      final adapter = _Adapter((request) {
        if (request.path == '/api/auth/login') {
          return _json(
            200,
            {
              'ok': true,
              'data': {
                'user': {'username': 'person'},
                'csrfToken': 't1',
              },
            },
            setCookie: ['sid=abc; Path=/; HttpOnly; Secure'],
          );
        }
        if (request.path == '/api/me') return _me();
        if (request.path == '/api/auth/csrf') {
          return _fail(401, 'AUTH_REQUIRED', 'انتهت');
        }
        return _fail(403, 'CSRF_REJECTED', 'CSRF rejected');
      });
      final layer = open(adapter, cookies);
      await layer.session.login(username: 'person', password: 'secret');

      await expectLater(
        layer.client.post('/api/collections', body: {'requestId': 'r1'}),
        throwsA(isA<CsrfInvalidException>()),
      );
      expect(adapter.count('/api/collections'), 1);
      expect(adapter.count('/api/auth/csrf'), 1);
      expect(layer.session.state, isA<SessionAuthenticated>());
      expect(await cookies.cookieHeader(), contains('sid=abc'));
    });
  });

  test('SSE stops after 401 instead of reconnecting', () async {
    var calls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://staging.example.invalid'))
      ..httpClientAdapter = _Adapter((_) {
        calls++;
        return _fail(401, 'AUTH_REQUIRED', 'انتهت');
      });
    final sse = SseRealtimeService(dio: dio, cursor: SequenceCursor());
    addTearDown(sse.dispose);
    await sse.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(sse.mode, RealtimeMode.stopped);
    expect(calls, 1);
  });

  test('polling stops after session expiry', () async {
    final api = _ExpiredClient();
    final polling = PollingRealtimeService(
      api: api,
      cursor: SequenceCursor(),
      interval: const Duration(hours: 1),
    );
    addTearDown(polling.dispose);
    await polling.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(api.calls, 1);
    expect(polling.mode, RealtimeMode.stopped);
  });
}

class _ExpiredClient implements ApiClient {
  int calls = 0;

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) async {
    calls++;
    throw const SessionExpiredException(statusCode: 419);
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      throw UnimplementedError();

  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      throw UnimplementedError();

  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      throw UnimplementedError();

  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    ApiRequestOptions options = const ApiRequestOptions(),
  }) =>
      throw UnimplementedError();
}
