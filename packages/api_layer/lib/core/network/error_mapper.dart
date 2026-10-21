import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Maps transport errors + the REAL error envelope to typed ApiExceptions.
/// Error envelope per API contract:
///   { "ok": false, "error": { "code": "AUTH_REQUIRED", "message": "...", "details": {...}, "correlationId": "uuid" } }
/// Observed server codes: AUTH_REQUIRED, VERSION_CONFLICT. Others are mapped by HTTP status.
class ErrorMapper {
  const ErrorMapper();

  /// Codes treated as "session expired" -> forced logout (no refresh flow).
  /// 🔶 Only AUTH_REQUIRED is observed. SESSION_EXPIRED, SESSION_REVOKED, and
  /// PAGE_EXPIRED are defensive. PAGE_EXPIRED is the stand-in for a codeless
  /// HTTP 419.
  ///
  /// Status wins after login: any authenticated 401, and any 419 that is not
  /// a CSRF error, is session expiry even when the code is something else.
  /// A 401 on the login request itself stays invalid credentials.
  static const sessionExpiredCodes = {
    'AUTH_REQUIRED',
    'SESSION_EXPIRED',
    'SESSION_REVOKED',
    'PAGE_EXPIRED',
  };

  /// 🔶 The real CSRF error code is NOT visible in the frontend code. Any code
  /// containing "CSRF" (e.g. CSRF_INVALID, CSRF_TOKEN_INVALID) is treated as such.
  static bool isCsrfCode(String code) => code.toUpperCase().contains('CSRF');

  /// 🔶 A CSRF failure may be named only in the server message.
  static bool isCsrfMessage(String? message) =>
      message != null && message.toUpperCase().contains('CSRF');

  static const invalidCredentialsMessage = 'بيانات الدخول غير صحيحة';

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
        // Newer dio values (e.g. transformTimeout) are not in the pinned enum.
        if (error.type.name.toLowerCase().contains('timeout')) {
          return const TimeoutApiException();
        }
        break;
    }

    final response = error.response;
    if (response == null) return const NetworkException();
    final authenticated = error.requestOptions.extra['skipAuth'] != true;
    return fromResponse(
      response.statusCode ?? 0,
      response.data,
      response.headers,
      authenticated,
    );
  }

  ApiException fromResponse(
    int status,
    Object? body, [
    Headers? headers,
    bool authenticated = true,
  ]) {
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
    final serverCode = err['code'] is String ? err['code'] as String : null;
    final serverMessage = _serverMessage(err, body);
    final code = (serverCode == null || serverCode.isEmpty)
        ? _defaultCode(status)
        : serverCode;
    final message = serverMessage ?? _defaultMessage(status);
    final details = err['details'] ?? (body is Map ? body['details'] : null);

    // CSRF wins over 419. A bare 419 is session expiry, not a token refresh.
    // HTML and empty bodies stay on the client default (see [_serverMessage]).
    if (isCsrfCode(code) || isCsrfMessage(serverMessage)) {
      return CsrfInvalidException(
          code: isCsrfCode(code) ? code : 'CSRF_INVALID',
          message: message,
          statusCode: status,
          correlationId: correlationId,
          details: details);
    }
    // The login call is unauthenticated. Its 401 is rejected credentials,
    // including when the body says AUTH_REQUIRED.
    if (status == 401 && !authenticated) {
      return InvalidCredentialsException(
          code: serverCode == null || serverCode.isEmpty
              ? 'INVALID_CREDENTIALS'
              : serverCode,
          message: serverMessage == null || serverMessage.isEmpty
              ? invalidCredentialsMessage
              : serverMessage,
          statusCode: status,
          correlationId: correlationId,
          details: details);
    }
    // After login, any 401 and any non-CSRF 419 end the session, whatever
    // the code is. Named session codes do the same on other statuses.
    if (sessionExpiredCodes.contains(code) ||
        (authenticated && status == 401) ||
        status == 419) {
      return SessionExpiredException(
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
        final fields = _fieldErrors(details);
        if (fields.isNotEmpty) {
          return ValidationException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details,
            fieldErrors: fields,
          );
        }
        return BadRequestException(
            code: code,
            message: message,
            statusCode: status,
            correlationId: correlationId,
            details: details);
      case 408:
        return TimeoutApiException(
            message: serverMessage ?? 'انتهت مهلة الاتصال',
            statusCode: status,
            correlationId: correlationId);
      case 401:
        // Unauthenticated 401 already returned above. Anything left is expiry.
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

  /// Message the server actually sent. HTML and empty bodies stay null so the
  /// client default is used instead of a proxy page.
  String? _serverMessage(Map<String, dynamic> err, Object? body) {
    final fromError = err['message'];
    if (fromError is String && fromError.trim().isNotEmpty) {
      return fromError.trim();
    }
    if (body is Map) {
      final top = body['message'];
      if (top is String && top.trim().isNotEmpty) return top.trim();
    }
    return null;
  }

  String _defaultCode(int status) => switch (status) {
        401 => 'AUTH_REQUIRED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        408 => 'TIMEOUT',
        409 => 'VERSION_CONFLICT',
        419 => 'PAGE_EXPIRED',
        422 => 'VALIDATION_ERROR',
        429 => 'RATE_LIMITED',
        _ when status >= 500 => 'SERVER_ERROR',
        _ => 'REQUEST_FAILED',
      };

  String _defaultMessage(int status) => switch (status) {
        401 || 419 => 'يجب تسجيل الدخول أولًا.',
        403 => 'لا تملك صلاحية لهذا الإجراء',
        404 => 'العنصر غير موجود',
        408 => 'انتهت مهلة الاتصال',
        409 => 'تغيرت البيانات على الخادم، يرجى التحديث',
        400 || 422 => 'البيانات المدخلة غير صحيحة',
        429 => 'طلبات كثيرة، حاول لاحقاً',
        _ when status >= 500 => 'خطأ في الخادم، حاول لاحقاً',
        _ => 'تعذر تنفيذ الطلب.',
      };
}

/// 401/419 (and [SessionExpiredException]) must not be retried by SSE or polling.
bool isUnrecoverableSessionError(Object error) {
  if (error is SessionExpiredException) return true;
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == 401 || status == 419;
  }
  return false;
}
