// P-09. INVALID_CURRENT_PASSWORD keeps the session. A real 401 wipes it once.
// Only the HTTP adapter is scripted. SessionManager and the interceptor are real.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = '555-0100';
const _token = 'not-a-real-token';
const _name = 'not-a-real-name';

void main() {
  test('wrong current password keeps the session; a real 401 wipes it once',
      () async {
    final cookies = InMemoryCookieStore();
    final adapter = _Script();
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://example.invalid',
        useFakeApi: false,
      ),
      cookieStore: cookies,
      httpClientAdapter: adapter,
    );
    addTearDown(layer.dispose);

    final reasons = <String?>[];
    final sub = layer.session.states.listen((state) {
      if (state is SessionUnauthenticated) reasons.add(state.reason);
    });
    addTearDown(sub.cancel);

    await layer.session.login(username: 'person', password: 'secret');
    expect(layer.session.state, isA<SessionAuthenticated>());
    expect(await cookies.cookieHeader(), contains('sid=abc'));

    final wrong = await _capture(
      layer.session.changePassword(
        currentPassword: 'secret',
        newPassword: '0123456789ab',
      ),
    );
    expect(wrong, isA<InvalidCurrentPasswordException>());
    expect(wrong, isNot(isA<SessionExpiredException>()));
    expect(wrong.message, 'كلمة المرور الحالية غير صحيحة');
    expect(wrong.message, isNot(contains(_phone)));
    expect(wrong.toString(), isNot(contains(_token)));
    expect(wrong.toString(), isNot(contains(_name)));
    expect(layer.session.state, isA<SessionAuthenticated>());
    expect(await cookies.cookieHeader(), contains('sid=abc'));
    expect(reasons, isEmpty);

    adapter.expire = true;
    final results = await Future.wait<Object>([
      _capture(layer.client.get('/api/me')),
      _capture(layer.client.get('/api/collections')),
    ]);
    expect(results, everyElement(isA<SessionExpiredException>()));
    expect(layer.session.state, isA<SessionUnauthenticated>());
    expect(
      (layer.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(reasons, ['session_expired']);
    expect(await cookies.isEmpty(), isTrue);
    expect(adapter.overlapped, isTrue);
  });

  test('a lookalike CSRF code or message does not refresh or replay', () async {
    final cookies = InMemoryCookieStore();
    final adapter = _WriteScript();
    final layer = _open(cookies, adapter);
    await layer.session.login(username: 'person', password: 'secret');
    expect(adapter.count('/api/auth/csrf'), 0);

    adapter.fail(
      status: 403,
      code: 'FOO_CSRF_BAR',
      message: 'CSRF token mismatch',
    );
    final lookalike = await _capture(
      layer.client.post('/api/collections', body: {'requestId': 'lookalike'}),
    );
    expect(lookalike, isA<ForbiddenException>());
    expect(lookalike.code, 'FOO_CSRF_BAR');
    expect(isCsrfRejection(lookalike), isFalse);
    expect(adapter.count('/api/collections'), 1);
    expect(adapter.count('/api/auth/csrf'), 0);
    expect(layer.session.state, isA<SessionAuthenticated>());

    adapter.fail(
      status: 400,
      code: 'VALIDATION_ERROR',
      message: 'the CSRF header was mentioned only in the sentence',
    );
    final mentioned = await _capture(
      layer.client.post('/api/collections', body: {'requestId': 'mentioned'}),
    );
    expect(mentioned, isA<BadRequestException>());
    expect(isCsrfRejection(mentioned), isFalse);
    expect(mentioned.message, contains('CSRF'));
    expect(adapter.count('/api/collections'), 2);
    expect(adapter.count('/api/auth/csrf'), 0);
    expect(layer.session.state, isA<SessionAuthenticated>());
  });

  test('a write is not replayed on CLIENT_VERSION_MISMATCH', () async {
    final cookies = InMemoryCookieStore();
    final adapter = _WriteScript();
    final layer = _open(cookies, adapter);
    await layer.session.login(username: 'person', password: 'secret');

    adapter.fail(
      status: 409,
      code: 'CLIENT_VERSION_MISMATCH',
      message: 'حدّث التطبيق من $_phone الرمز $_token عن $_name',
    );
    final error = await _capture(
      layer.client.post('/api/collections', body: {'requestId': 'version'}),
    );
    expect(error, isA<ClientVersionMismatchException>());
    expect(error, isNot(isA<ConflictException>()));
    expect(isCsrfRejection(error), isFalse);
    expect(error.message, 'حدّث التطبيق');
    expect(error.message, isNot(contains(_phone)));
    expect(error.toString(), isNot(contains(_token)));
    expect(error.toString(), isNot(contains(_name)));
    expect(adapter.count('/api/collections'), 1);
    expect(adapter.count('/api/auth/csrf'), 0);
    expect(layer.session.state, isA<SessionAuthenticated>());
    expect(await cookies.cookieHeader(), contains('sid=abc'));
  });
}

ApiLayer _open(InMemoryCookieStore cookies, HttpClientAdapter adapter) {
  final layer = ApiLayer.create(
    config: const ApiConfig(
      baseUrl: 'https://example.invalid',
      useFakeApi: false,
    ),
    cookieStore: cookies,
    httpClientAdapter: adapter,
  );
  addTearDown(layer.dispose);
  return layer;
}

Future<ApiException> _capture(Future<void> call) async {
  try {
    await call;
  } on ApiException catch (error) {
    return error;
  }
  throw StateError('the call succeeded');
}

class _WriteScript implements HttpClientAdapter {
  final Map<String, int> _counts = {};
  int? _status;
  String? _code;
  String? _message;

  int count(String path) => _counts[path] ?? 0;

  void fail({
    required int status,
    required String code,
    required String message,
  }) {
    _status = status;
    _code = code;
    _message = message;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    _counts[path] = count(path) + 1;
    if (path == '/api/auth/login') {
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
    if (path == '/api/me') return _me();
    if (path == '/api/auth/csrf') {
      return _json(200, {
        'ok': true,
        'data': {'csrfToken': 't2'},
      });
    }
    final status = _status;
    final code = _code;
    final message = _message;
    if (status != null && code != null && message != null) {
      return _json(status, {
        'ok': false,
        'error': {
          'code': code,
          'message': message,
          'details': {
            'phone': _phone,
            'token': _token,
            'name': _name,
          },
          'correlationId': 'corr-write',
        },
      });
    }
    return _json(404, {
      'ok': false,
      'error': {'code': 'NOT_FOUND', 'message': 'العنصر غير موجود'},
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Script implements HttpClientAdapter {
  bool expire = false;
  int _expiredStarts = 0;
  Completer<void>? _both;
  bool overlapped = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path == '/api/auth/login') {
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
    if (path == '/api/me' && !expire) return _me();
    if (path == '/api/auth/csrf') {
      return _json(200, {
        'ok': true,
        'data': {'csrfToken': 't2'},
      });
    }
    if (path == '/api/auth/change-password') {
      return _json(401, {
        'ok': false,
        'error': {
          'code': 'INVALID_CURRENT_PASSWORD',
          'message': 'كلمة $_name هاتف $_phone رمز $_token',
          'details': {
            'phone': _phone,
            'token': _token,
            'name': _name,
            'amountUnits': 250,
          },
          'correlationId': 'corr-password',
        },
      });
    }
    if (expire) {
      _expiredStarts++;
      _both ??= Completer<void>();
      if (_expiredStarts >= 2) {
        overlapped = true;
        if (!_both!.isCompleted) _both!.complete();
      }
      await _both!.future;
      return _json(401, {
        'ok': false,
        'error': {
          'code': 'AUTH_REQUIRED',
          'message': 'انتهت الجلسة',
          'correlationId': 'corr-session',
        },
      });
    }
    return _json(404, {
      'ok': false,
      'error': {'code': 'NOT_FOUND', 'message': 'العنصر غير موجود'},
    });
  }

  @override
  void close({bool force = false}) {}
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
