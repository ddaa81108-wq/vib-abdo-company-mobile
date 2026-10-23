// P-09 / G-07. One case per code in docs/api/error-catalog.json.
// The expected type is the contract. The mapper is the code under test.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/auth/auth_strategy.dart';
import 'package:flutter_api_layer/core/auth/cookie_csrf_auth_strategy.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = '555-0100';
const _token = 'not-a-real-token';
const _secret = 'not-a-real-secret';
const _name = 'not-a-real-name';

const _fixedMessages = <String, String>{
  'CSRF_REJECTED': 'رمز حماية الطلب غير صالح',
  'MFA_REQUIRED': 'غير مدعوم في التطبيق',
  'INVALID_CURRENT_PASSWORD': 'كلمة المرور الحالية غير صحيحة',
  'CLIENT_VERSION_MISMATCH': 'حدّث التطبيق',
  'PENDING_SUBMISSION_EXISTS': 'يوجد تقديم معلّق لهذا التكليف',
  'FULL_AMOUNT_CHANGED': 'تغيّر مبلغ السداد الكامل',
  'NO_POSITIVE_DEBT': 'لا يوجد دين موجب',
  'DUPLICATE_SAME_WORKDAY': 'توجد عملية مشابهة في يوم العمل',
  'REQUEST_ID_REUSED': 'استُخدم معرّف الطلب لمحتوى مختلف',
};

void main() {
  const mapper = ErrorMapper();
  final byCode = _codesByStatus(_catalogFile());

  for (final code in byCode.keys) {
    test('catalog $code', () {
      for (final status in byCode[code]!) {
        final error = mapper.fromResponse(status, _envelope(code));
        expect(
          error.runtimeType,
          _expected(code, status, authenticated: true),
          reason: '$code $status',
        );
        expect(error.code, code);
        _expectNoSecrets(error);
        final fixed = _fixedMessages[code];
        if (fixed != null) {
          expect(error.message, fixed);
          expect(error, isNot(isA<ConflictException>()));
        }
        if (code == 'VERSION_CONFLICT') {
          expect(error, isA<ConflictException>());
          expect((error as ConflictException).isVersionConflict, isTrue);
          expect(error.message, 'تم تعديل البيانات من مستخدم آخر');
        }
        if (code == 'CLIENT_VERSION_MISMATCH') {
          expect(error, isNot(isA<ConflictException>()));
        }
        if (code == 'CSRF_REJECTED') {
          expect(isCsrfRejection(error), isTrue);
          expect(error, isA<CsrfRejectedException>());
          expect(error, isA<CsrfInvalidException>());
          expect(error, isNot(isA<ForbiddenException>()));
        }
        if (code == 'MFA_REQUIRED') {
          final login = mapper.fromResponse(
            status,
            _envelope(code),
            null,
            false,
          );
          expect(login, isA<MfaRequiredException>());
          expect(login, isNot(isA<InvalidCredentialsException>()));
          expect(login.message, 'غير مدعوم في التطبيق');
          _expectNoSecrets(login);
        }
        if (code == 'INVALID_CURRENT_PASSWORD') {
          final attempt = mapper.fromResponse(
            status,
            _envelope(code),
            null,
            false,
          );
          expect(attempt, isA<InvalidCurrentPasswordException>());
          expect(attempt, isNot(isA<SessionExpiredException>()));
          _expectNoSecrets(attempt);
        }
        if (code == 'INVALID_CREDENTIALS' || code == 'AUTH_REQUIRED') {
          final login = mapper.fromResponse(
            status,
            _envelope(code),
            null,
            false,
          );
          expect(login, isA<InvalidCredentialsException>());
          _expectNoSecrets(login);
        }
      }
    });
  }

  test('details.field is the field name', () {
    final error = mapper.fromResponse(400, {
      'ok': false,
      'error': {
        'code': 'INVALID_AMOUNT',
        'message': 'القيمة المالية يجب أن تكون رقمًا صحيحًا موجبًا بدون كسور.',
        'details': {
          'field': 'inputValue',
          'password': _secret,
          'phone': _phone,
          'token': _token,
          'name': _name,
          'amountUnits': 250,
        },
        'correlationId': 'corr-field',
      },
    });
    expect(error, isA<ValidationException>());
    final field = (error as ValidationException).fieldErrors.single;
    expect(field.field, 'inputValue');
    expect(field.message, isNot('inputValue'));
    expect(field.message, isEmpty);
    expect(error.message, isNot(contains('inputValue')));
    _expectNoSecrets(error);
  });

  test('an unknown code follows the HTTP status', () {
    final conflict = mapper.fromResponse(
      409,
      _envelope('NOT_A_CATALOG_CODE', message: 'اتصل $_phone الرمز $_token'),
    );
    expect(conflict, isA<ConflictException>());
    expect(conflict.code, 'NOT_A_CATALOG_CODE');
    expect((conflict as ConflictException).isVersionConflict, isFalse);
    expect(conflict.message, 'تغيرت البيانات على الخادم، يرجى التحديث');
    _expectNoSecrets(conflict);

    final odd = mapper.fromResponse(418, _envelope('NOT_A_CATALOG_CODE'));
    expect(odd, isA<UnknownApiException>());
    expect(odd.code, 'NOT_A_CATALOG_CODE');
    _expectNoSecrets(odd);
  });

  test('VERSION_CONFLICT without a server sentence keeps its own message', () {
    final error = mapper.fromResponse(409, {
      'ok': false,
      'error': {
        'code': 'VERSION_CONFLICT',
        'details': {'phone': _phone, 'currentVersion': 4},
      },
    });
    expect(error, isA<ConflictException>());
    expect(error.message, 'تغيرت البيانات على الخادم، يرجى التحديث');
    _expectNoSecrets(error);
  });

  test('CSRF_REJECTED is the signal the strategy refreshes once', () async {
    final error = mapper.fromResponse(403, _envelope('CSRF_REJECTED'));
    expect(isCsrfRejection(error), isTrue);
    expect(
      isCsrfRejection(mapper.fromResponse(419, _envelope('CSRF_REJECTED'))),
      isFalse,
    );
    expect(
      isCsrfRejection(mapper.fromResponse(403, _envelope('CSRF_MISSING'))),
      isFalse,
    );
    expect(
        isCsrfRejection(const ConflictException(
          code: 'VERSION_CONFLICT',
          message: 'تغيرت البيانات على الخادم، يرجى التحديث',
        )),
        isFalse);

    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.httpClientAdapter = _CsrfAdapter();
    final strategy = CookieCsrfAuthStrategy(
      cookieStore: InMemoryCookieStore(),
      bareDio: dio,
    );
    final first = await strategy.handleAuthError(
      error,
      RequestOptions(path: '/api/collections', method: 'POST'),
      authenticated: true,
    );
    expect(first, AuthErrorAction.retryOnce);
    final replayed = RequestOptions(path: '/api/collections', method: 'POST')
      ..extra['authRetried'] = true;
    final second = await strategy.handleAuthError(
      error,
      replayed,
      authenticated: true,
    );
    expect(second, AuthErrorAction.passThrough);
  });
}

Type _expected(String code, int status, {required bool authenticated}) {
  if (code == 'CSRF_REJECTED') return CsrfRejectedException;
  if (code.toUpperCase().contains('CSRF')) return CsrfInvalidException;
  switch (code) {
    case 'MFA_REQUIRED':
      return MfaRequiredException;
    case 'INVALID_CURRENT_PASSWORD':
      return InvalidCurrentPasswordException;
    case 'CLIENT_VERSION_MISMATCH':
      return ClientVersionMismatchException;
    case 'PENDING_SUBMISSION_EXISTS':
      return PendingSubmissionExistsException;
    case 'FULL_AMOUNT_CHANGED':
      return FullAmountChangedException;
    case 'NO_POSITIVE_DEBT':
      return NoPositiveDebtException;
    case 'DUPLICATE_SAME_WORKDAY':
      return DuplicateSameWorkdayException;
    case 'REQUEST_ID_REUSED':
      return RequestIdReusedException;
  }
  if (!authenticated && status == 401) return InvalidCredentialsException;
  if (ErrorMapper.sessionExpiredCodes.contains(code) ||
      (authenticated && status == 401) ||
      status == 419) {
    return SessionExpiredException;
  }
  if (code == 'VERSION_CONFLICT') return ConflictException;
  return switch (status) {
    400 => BadRequestException,
    403 => ForbiddenException,
    404 => NotFoundException,
    408 => TimeoutApiException,
    409 || 412 => ConflictException,
    422 => ValidationException,
    423 => AccountLockedException,
    426 => UpgradeRequiredException,
    429 => RateLimitedException,
    _ when status >= 500 => ServerException,
    _ => UnknownApiException,
  };
}

Map<String, Object?> _envelope(String code, {String? message}) {
  final fixed = _fixedMessages.containsKey(code);
  return {
    'ok': false,
    'error': {
      'code': code,
      'message': message ??
          (code == 'VERSION_CONFLICT'
              ? 'تم تعديل البيانات من مستخدم آخر'
              : (fixed ? 'اتصل $_phone الرمز $_token عن $_name' : 'تعذر')),
      'details': {
        'phone': _phone,
        'token': _token,
        'password': _secret,
        'name': _name,
        'amountUnits': 250,
      },
      'correlationId': 'corr-catalog',
    },
  };
}

void _expectNoSecrets(ApiException error) {
  for (final secret in [_phone, _token, _secret, _name, '250']) {
    expect(error.message, isNot(contains(secret)), reason: error.code);
    expect(error.toString(), isNot(contains(secret)), reason: error.code);
  }
}

Map<String, Set<int>> _codesByStatus(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map || decoded['errors'] is! List) {
    throw StateError('error catalog has no errors list');
  }
  final grouped = <String, Set<int>>{};
  for (final row in decoded['errors'] as List) {
    final item = Map<String, Object?>.from(row as Map);
    final code = item['codeOrEntity']! as String;
    final status = item['httpStatus']! as int;
    grouped.putIfAbsent(code, () => {}).add(status);
  }
  if (grouped.isEmpty) throw StateError('error catalog is empty');
  return grouped;
}

File _catalogFile() {
  for (final path in [
    'docs/api/error-catalog.json',
    '../../docs/api/error-catalog.json',
  ]) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  throw StateError('docs/api/error-catalog.json was not found');
}

class _CsrfAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'ok': true,
        'data': {'csrfToken': 'refreshed'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
