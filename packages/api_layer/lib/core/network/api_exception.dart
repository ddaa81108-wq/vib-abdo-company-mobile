/// Typed exceptions produced by ErrorMapper from the REAL error envelope:
/// { "ok": false, "error": { "code", "message", "details", "correlationId" } }
/// `correlationId` (also sent as the `x-correlation-id` response header) is the
/// ONLY identifier that may be logged; it carries no PII.
sealed class ApiException implements Exception {
  const ApiException(
      {required this.code,
      required this.message,
      this.statusCode,
      this.correlationId,
      this.details});

  final String code;
  final String message; // user-displayable (server-provided when available)
  final int? statusCode;
  final String? correlationId;

  /// Raw `error.details` from the server. Never logged (may contain PII).
  final Object? details;

  @override
  String toString() =>
      '$runtimeType(code: $code, status: $statusCode, correlationId: $correlationId)';
}

class FieldError {
  const FieldError(
      {required this.field, required this.code, required this.message});
  final String field;
  final String code;
  final String message;
}

/// Client-side code used by the existing web client too: NETWORK_UNAVAILABLE.
class NetworkException extends ApiException {
  const NetworkException({super.message = 'تعذر تنفيذ الطلب. تحقق من الاتصال.'})
      : super(code: 'NETWORK_UNAVAILABLE');
}

class TimeoutApiException extends ApiException {
  const TimeoutApiException({
    super.message = 'انتهت مهلة الاتصال',
    super.statusCode,
    super.correlationId,
  }) : super(code: 'TIMEOUT');
}

/// Client-side code used by the existing web client too: INVALID_SERVER_RESPONSE.
class InvalidServerResponseException extends ApiException {
  const InvalidServerResponseException(
      {super.message = 'استجابة الخادم غير صالحة',
      super.statusCode,
      super.correlationId})
      : super(code: 'INVALID_SERVER_RESPONSE');
}

class BadRequestException extends ApiException {
  const BadRequestException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

/// 401 that is not a session expiry (kept for completeness).
class UnauthorizedException extends ApiException {
  const UnauthorizedException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

class InvalidCredentialsException extends ApiException {
  const InvalidCredentialsException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

/// AUTH_REQUIRED / session expired or revoked -> SessionManager.forceLogout (no refresh flow).
class SessionExpiredException extends ApiException {
  const SessionExpiredException(
      {super.code = 'AUTH_REQUIRED',
      super.message = 'انتهت الجلسة، يرجى تسجيل الدخول',
      super.statusCode,
      super.correlationId,
      super.details});
}

/// CSRF token missing/invalid. AuthInterceptor refetches the token ONCE and retries.
class CsrfInvalidException extends ApiException {
  const CsrfInvalidException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

class ForbiddenException extends ApiException {
  const ForbiddenException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

class NotFoundException extends ApiException {
  const NotFoundException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

/// VERSION_CONFLICT (stale expectedVersion / expectedDayVersion / expectedFinancialVersion)
/// and other 409s. UI must refetch and show the server's current state.
class ConflictException extends ApiException {
  const ConflictException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
  bool get isVersionConflict => code == 'VERSION_CONFLICT';
}

class ValidationException extends ApiException {
  const ValidationException(
      {required super.code,
      required super.message,
      this.fieldErrors = const [],
      super.statusCode,
      super.correlationId,
      super.details});
  final List<FieldError> fieldErrors;
}

class AccountLockedException extends ApiException {
  const AccountLockedException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

class UpgradeRequiredException extends ApiException {
  const UpgradeRequiredException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

class RateLimitedException extends ApiException {
  const RateLimitedException(
      {required super.code,
      required super.message,
      this.retryAfter,
      super.statusCode,
      super.correlationId,
      super.details});
  final Duration? retryAfter;
}

class ServerException extends ApiException {
  const ServerException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

/// Client-side code used by the existing web client too: REQUEST_FAILED.
class UnknownApiException extends ApiException {
  const UnknownApiException(
      {super.code = 'REQUEST_FAILED',
      super.message = 'تعذر تنفيذ الطلب.',
      super.statusCode,
      super.correlationId,
      super.details});
}
