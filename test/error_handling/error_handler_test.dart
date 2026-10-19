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
      'correlationId': 'corr-1',
      'balanceUnits': 320,
    });
    expect(redacted, {
      'password': '***',
      'correlationId': 'corr-1',
      'balanceUnits': '***',
    });
  });
}
