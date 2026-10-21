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

  test('validation field messages are shown and details are not', () {
    const error = ValidationException(
      code: 'VALIDATION_ERROR',
      message: 'البيانات المدخلة غير صحيحة',
      statusCode: 422,
      correlationId: 'corr-2',
      details: {'password': 'not-a-real-secret'},
      fieldErrors: [
        FieldError(field: 'name', code: 'REQUIRED', message: 'الاسم مطلوب'),
        FieldError(
          field: 'amount',
          code: 'INVALID',
          message: 'المبلغ غير صالح',
        ),
      ],
    );
    final failure = handler.toFailure(error);
    expect(failure.code, 'VALIDATION_ERROR');
    expect(failure.correlationId, 'corr-2');
    expect(
      failure.message,
      'البيانات المدخلة غير صحيحة\nالاسم مطلوب\nالمبلغ غير صالح',
    );
    expect(failure.message.contains('not-a-real-secret'), isFalse);
    expect(failure.diagnostic.contains('not-a-real-secret'), isFalse);
    expect(failure.diagnostic, 'code=VALIDATION_ERROR correlationId=corr-2');
  });

  test('network, timeout, and server failures keep their codes', () {
    expect(
      handler.toFailure(const NetworkException()).code,
      'NETWORK_UNAVAILABLE',
    );
    expect(handler.toFailure(const TimeoutApiException()).code, 'TIMEOUT');
    expect(
      handler
          .toFailure(
            const ServerException(
              code: 'SERVER_ERROR',
              message: 'خطأ في الخادم، حاول لاحقاً',
              statusCode: 503,
            ),
          )
          .message,
      'خطأ في الخادم، حاول لاحقاً',
    );
  });

  test(
    'DAY_FINALIZED keeps the server message and is not a version conflict',
    () {
      const error = ConflictException(
        code: 'DAY_FINALIZED',
        message: 'اليوم مرحّل. لا يمكن إضافة أو تعديل أو حذف بند.',
        statusCode: 409,
        correlationId: 'corr-day',
      );
      final failure = handler.toFailure(error);
      expect(failure.code, 'DAY_FINALIZED');
      expect(failure.message, error.message);
      expect(failure.correlationId, 'corr-day');
      expect(error.isVersionConflict, isFalse);
    },
  );

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
