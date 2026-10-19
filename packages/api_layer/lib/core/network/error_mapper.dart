import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Maps transport errors + the REAL error envelope to typed ApiExceptions.
/// Envelope (observed on the existing system, analysis doc §4.3):
///   { "ok": false, "error": { "code": "AUTH_REQUIRED", "message": "...", "details": {...}, "correlationId": "uuid" } }
/// Observed server codes: AUTH_REQUIRED, VERSION_CONFLICT. Others are mapped by HTTP status.
class ErrorMapper {
  const ErrorMapper();

  /// Codes treated as "session expired" -> forced logout (no refresh flow exists).
  /// 🔶 Only AUTH_REQUIRED is observed; the others are defensive guesses.
  static const sessionExpiredCodes = {
    'AUTH_REQUIRED',
    'SESSION_EXPIRED',
    'SESSION_REVOKED'
  };

  /// 🔶 The real CSRF error code is NOT visible in the frontend code. Any code
  /// containing "CSRF" (e.g. CSRF_INVALID, CSRF_TOKEN_INVALID) is treated as such.
  static bool isCsrfCode(String code) => code.toUpperCase().contains('CSRF');

  ApiException map(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return const UnknownApiException();
    if (error.error is ApiException) return error.error as ApiException;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutApiException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        // Possible MITM / pinning failure. Never expose details.
        return const NetworkException(message: 'تعذر التحقق من أمان الاتصال');
      case DioExceptionType.cancel:
        return const UnknownApiException(
            code: 'CANCELLED', message: 'أُلغي الطلب');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
      default:
        // Newer dio values (e.g. transformTimeout in recent dio 5.x) fall through to
        // response-based mapping; kept as `default` to stay compatible with dio ^5.4.
        break;
    }

    final response = error.response;
    if (response == null) return const NetworkException();
    return fromResponse(
        response.statusCode ?? 0, response.data, response.headers);
  }

  ApiException fromResponse(int status, Object? body, [Headers? headers]) {
    final hasEnvelope =
        body is Map && body['ok'] == false && body['error'] is Map;
    final err = hasEnvelope
        ? Map<String, dynamic>.from(body['error'] as Map)
        : const <String, dynamic>{};
    final correlationId =
        (err['correlationId'] as String?) ?? headers?.value('x-correlation-id');
    if (!hasEnvelope && body is! Map) {
      // Non-JSON / truncated body (e.g. proxy/Cloudflare page).
      if (status >= 200 && status < 300) {
        return InvalidServerResponseException(
            statusCode: status, correlationId: correlationId);
      }
    }
    final code = (err['code'] as String?) ?? _defaultCode(status);
    final message = (err['message'] as String?) ?? _defaultMessage(status);
    final details = err['details'];

    // Code-first mapping (real codes), then status.
    if (sessionExpiredCodes.contains(code)) {
      return SessionExpiredException(
          code: code,
          message: message,
          statusCode: status,
          correlationId: correlationId,
          details: details);
    }
    if (isCsrfCode(code)) {
      return CsrfInvalidException(
          code: code,
          message: message,
          statusCode: status,
          correlationId: correlationId,
          details: details);
    }
    if (code == 'VERSION_CONFLICT') {
      return ConflictException(
          code: code,
          message: message,
          statusCode: status,
          correlationId: correlationId,
          details: details);
    }

    switch (status) {
      case 400:
        return BadRequestException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 401:
        if (code.contains('CREDENTIALS') || code.contains('LOGIN')) {
          return InvalidCredentialsException(
              code: code,
              message: message,
              statusCode: status,
              correlationId: correlationId,
              details: details);
        }
        // 🔶 Any other 401 is treated as session expiry (cookie session has no refresh).
        return SessionExpiredException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 403:
        return ForbiddenException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 404:
        return NotFoundException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 409:
      case 412:
        return ConflictException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 422:
        return ValidationException(
          code: code,
          message: message,
          statusCode: status,
          correlationId: correlationId,
          details: details,
          fieldErrors: _fieldErrors(details),
        );
      case 423:
        return AccountLockedException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 426:
        return UpgradeRequiredException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 429:
        final ra = int.tryParse(headers?.value('retry-after') ?? '');
        return RateLimitedException(
          code: code,
          message: message,
          statusCode: status,
          correlationId: correlationId,
          details: details,
          retryAfter: ra == null ? null : Duration(seconds: ra),
        );
      default:
        if (status >= 500) {
          return ServerException(
              code: code,
              message: message,
              statusCode: status,
              correlationId: correlationId,
              details: details);
        }
        return UnknownApiException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
    }
  }

  /// `details` is an object on the real server (shape unknown 🔶). Accept either
  /// { "fields": { "name": "msg" } }, { "name": "msg" } or [ {field, code, message} ].
  List<FieldError> _fieldErrors(Object? details) {
    if (details is List) {
      return details
          .whereType<Map>()
          .map((d) => FieldError(
              field: '${d['field'] ?? ''}',
              code: '${d['code'] ?? ''}',
              message: '${d['message'] ?? ''}'))
          .toList(growable: false);
    }
    if (details is Map) {
      final fields =
          details['fields'] is Map ? details['fields'] as Map : details;
      return fields.entries
          .where((e) => e.value is String)
          .map((e) => FieldError(
              field: '${e.key}', code: 'INVALID', message: e.value as String))
          .toList(growable: false);
    }
    return const [];
  }

  String _defaultCode(int status) => switch (status) {
        401 => 'AUTH_REQUIRED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        409 => 'VERSION_CONFLICT',
        422 => 'VALIDATION_ERROR',
        429 => 'RATE_LIMITED',
        _ when status >= 500 => 'SERVER_ERROR',
        _ => 'REQUEST_FAILED',
      };

  String _defaultMessage(int status) => switch (status) {
        401 => 'يجب تسجيل الدخول أولًا.',
        403 => 'لا تملك صلاحية لهذا الإجراء',
        404 => 'العنصر غير موجود',
        409 => 'تغيرت البيانات على الخادم، يرجى التحديث',
        422 => 'البيانات المدخلة غير صحيحة',
        429 => 'طلبات كثيرة، حاول لاحقاً',
        _ when status >= 500 => 'خطأ في الخادم، حاول لاحقاً',
        _ => 'تعذر تنفيذ الطلب.',
      };
}
