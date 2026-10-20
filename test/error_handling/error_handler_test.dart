import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/authentication/login_form_error.dart';
import 'package:vib_abdo_company_mobile/error_handling/error_handler.dart';

void main() {
  const handler = ErrorHandler();

  test('server message and correlation id are kept, details are not', () {
    const error = InvalidCredentialsException(
      code: 'INVALID_CREDENTIALS',
      message: 'بيانات الدخول غير صحيحة',
      statusCode: 401,
      correlationId: 'corr-1',
      details: {'password': 'not-a-real-secret'},
    );
    final failure = handler.toFailure(error);
    expect(failure.message, 'بيانات الدخول غير صحيحة');
    expect(failure.code, 'INVALID_CREDENTIALS');
    expect(failure.correlationId, 'corr-1');
    expect(failure.diagnostic, 'code=INVALID_CREDENTIALS correlationId=corr-1');
    expect(failure.diagnostic.contains('not-a-real-secret'), isFalse);
    expect(failure.message.contains('not-a-real-secret'), isFalse);
  });

  test('form errors stay user-facing and unknown errors stay generic', () {
    expect(
      handler.toFailure(const LoginFormError('أدخل الاسم')).message,
      'أدخل الاسم',
    );
    expect(handler.toFailure(StateError('boom')).code, 'REQUEST_FAILED');
  });

  test('structured values are redacted before logging', () {
    final redacted = handler.redact({
      'password': 'not-a-real-secret',
      'current_password': 'also-secret',
      'createdByName': 'Person',
      'displayNote': 'private',
      'correlationId': 'corr-1',
      'balanceUnits': 320,
    });
    expect(redacted, {
      'password': '***',
      'current_password': '***',
      'createdByName': '***',
      'displayNote': '***',
      'correlationId': 'corr-1',
      'balanceUnits': '***',
    });
  });

  test(
    'a bearer token in the server message is removed, Arabic text stays',
    () {
      const error = BadRequestException(
        code: 'BAD_REQUEST',
        message: 'Bearer leak-token — بيانات غير مقبولة',
        correlationId: 'cid-9',
      );
      final failure = handler.toFailure(error);
      expect(failure.message, isNot(contains('leak-token')));
      expect(failure.message, contains('بيانات غير مقبولة'));
      expect(failure.diagnostic, 'code=BAD_REQUEST correlationId=cid-9');
    },
  );

  test('report and framework hooks do not dump the raw exception', () {
    final logs = <String>[];
    final previousPrint = debugPrint;
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = previousPrint;
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
    });

    const leaked =
        'password=super-secret Bearer leak-token session=leak-cookie';
    handler.report(StateError(leaked));
    installErrorHooks(handler);
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError(leaked), library: 'test'),
    );
    final handled = PlatformDispatcher.instance.onError!(
      StateError(leaked),
      StackTrace.empty,
    );
    expect(handled, isTrue);

    final text = logs.join('\n');
    expect(text, contains('code=REQUEST_FAILED'));
    expect(text, isNot(contains('super-secret')));
    expect(text, isNot(contains('leak-token')));
    expect(text, isNot(contains('leak-cookie')));
  });
}
