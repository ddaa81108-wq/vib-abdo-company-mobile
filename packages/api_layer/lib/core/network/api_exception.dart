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

/// A CSRF-shaped failure that is not the catalog code.
///
/// Refresh-once is [CsrfRejectedException] only. This type does not refresh.
class CsrfInvalidException extends ApiException {
  const CsrfInvalidException(
      {required super.code,
      required super.message,
      super.statusCode,
      super.correlationId,
      super.details});
}

/// `403 CSRF_REJECTED`. The cookie strategy refetches the token once and replays once.
///
/// The write queue is P-10. This type is only the recognition signal.
class CsrfRejectedException extends CsrfInvalidException {
  const CsrfRejectedException({
    super.message = 'رمز حماية الطلب غير صالح',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'CSRF_REJECTED');
}

/// True only for the catalog code `CSRF_REJECTED`.
///
/// A different code, or a message that mentions CSRF, is not a rejection.
/// The cookie strategy refreshes once for this signal only. It does not queue writes.
bool isCsrfRejection(Object error) =>
    error is CsrfRejectedException && error.code == 'CSRF_REJECTED';

/// `401 MFA_REQUIRED`. The app has no MFA flow.
class MfaRequiredException extends ApiException {
  const MfaRequiredException({
    super.message = 'غير مدعوم في التطبيق',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'MFA_REQUIRED');
}

/// `401 INVALID_CURRENT_PASSWORD` on change-password. Does not end the session.
class InvalidCurrentPasswordException extends ApiException {
  const InvalidCurrentPasswordException({
    super.message = 'كلمة المرور الحالية غير صحيحة',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'INVALID_CURRENT_PASSWORD');
}

/// `409 CLIENT_VERSION_MISMATCH`. Not a data conflict.
class ClientVersionMismatchException extends ApiException {
  const ClientVersionMismatchException({
    super.message = 'حدّث التطبيق',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'CLIENT_VERSION_MISMATCH');
}

/// `409 PENDING_SUBMISSION_EXISTS`.
class PendingSubmissionExistsException extends ApiException {
  const PendingSubmissionExistsException({
    super.message = 'يوجد تقديم معلّق لهذا التكليف',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'PENDING_SUBMISSION_EXISTS');
}

/// `409 FULL_AMOUNT_CHANGED`.
class FullAmountChangedException extends ApiException {
  const FullAmountChangedException({
    super.message = 'تغيّر مبلغ السداد الكامل',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'FULL_AMOUNT_CHANGED');
}

/// `409 NO_POSITIVE_DEBT`.
class NoPositiveDebtException extends ApiException {
  const NoPositiveDebtException({
    super.message = 'لا يوجد دين موجب',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'NO_POSITIVE_DEBT');
}

/// `409 DUPLICATE_SAME_WORKDAY`.
class DuplicateSameWorkdayException extends ApiException {
  const DuplicateSameWorkdayException({
    super.message = 'توجد عملية مشابهة في يوم العمل',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'DUPLICATE_SAME_WORKDAY');
}

/// `409 REQUEST_ID_REUSED`.
class RequestIdReusedException extends ApiException {
  const RequestIdReusedException({
    super.message = 'استُخدم معرّف الطلب لمحتوى مختلف',
    super.statusCode,
    super.correlationId,
    super.details,
  }) : super(code: 'REQUEST_ID_REUSED');
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
