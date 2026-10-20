import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/core/network/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logging is off unless asked, and the line has no secrets', () {
    expect(SafeLoggingInterceptor().enabled, isFalse);

    final options = RequestOptions(
      path: '/api/me',
      baseUrl: 'https://user:secret-pass@staging.example.invalid',
      method: 'POST',
      queryParameters: {'access_token': 'leak-token', 'password': 'leak-pw'},
      headers: {
        'Cookie': 'session=leak-cookie',
        'Authorization': 'Bearer leak-bearer',
        'X-CSRF-Token': 'leak-csrf',
      },
      data: {'password': 'body-secret', 'username': 'person@example.com'},
    );
    options.extra['_t0'] = DateTime.now().millisecondsSinceEpoch;

    final interceptor = SafeLoggingInterceptor(enabled: true);
    final line = interceptor.formatLog(options, 201, 'cid-1');
    expect(line, contains('POST'));
    expect(line, contains('/api/me'));
    expect(line, contains('201'));
    expect(line, contains('cid-1'));
    expect(line, isNot(contains('?')));
    expect(line, isNot(contains('staging.example')));
    expect(line, isNot(contains('secret-pass')));
    expect(line, isNot(contains('leak-')));
    expect(line, isNot(contains('body-secret')));
    expect(line, isNot(contains('person@example.com')));
    expect(line, isNot(contains('Cookie')));
    expect(line, isNot(contains('access_token')));

    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };
    addTearDown(() => debugPrint = previous);

    SafeLoggingInterceptor(enabled: false).onResponse(
      Response(
        requestOptions: options,
        statusCode: 201,
        data: {'password': 'body-secret'},
        headers: Headers.fromMap({
          'set-cookie': ['session=leak-cookie'],
          'x-correlation-id': ['cid-1'],
        }),
      ),
      ResponseInterceptorHandler(),
    );
    expect(logs, isEmpty);

    interceptor.onResponse(
      Response(
        requestOptions: options,
        statusCode: 201,
        data: {'password': 'body-secret'},
        headers: Headers.fromMap({
          'set-cookie': ['session=leak-cookie'],
          'x-correlation-id': ['cid-1'],
        }),
      ),
      ResponseInterceptorHandler(),
    );
    expect(logs, hasLength(1));
    expect(logs.single, isNot(contains('leak-')));
    expect(logs.single, isNot(contains('body-secret')));
  });

  test('a poisoned correlation id is scrubbed', () {
    final options = RequestOptions(
      path: '/api/me',
      baseUrl: 'https://staging.example.invalid',
      method: 'GET',
    );
    final line = SafeLoggingInterceptor(enabled: true)
        .formatLog(options, 200, 'session=leak-cookie');
    expect(line, isNot(contains('leak-cookie')));
  });
}
