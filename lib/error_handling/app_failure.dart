/// What the UI is allowed to show after [ErrorHandler] maps an error.
class AppFailure {
  const AppFailure({
    required this.message,
    required this.code,
    this.correlationId,
  });

  final String message;
  final String code;
  final String? correlationId;

  /// Safe log line: code and correlation id only.
  String get diagnostic => 'code=$code correlationId=${correlationId ?? '-'}';

  /// Unified 403 (`FORBIDDEN` or catalog `PERMISSION_DENIED`).
  /// The server sends `FORBIDDEN` or `PERMISSION_DENIED`.
  /// The screen shows `AppStrings.forbidden`, the same sentence as
  /// `ForbiddenPane`, and does not show the server envelope text.
  bool get isForbidden => code == 'FORBIDDEN' || code == 'PERMISSION_DENIED';
}
