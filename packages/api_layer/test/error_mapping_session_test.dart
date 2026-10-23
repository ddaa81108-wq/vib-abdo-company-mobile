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
}

Future<ApiException> _capture(Future<void> call) async {
  try {
    await call;
  } on ApiException catch (error) {
    return error;
  }
  throw StateError('the call succeeded');
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
