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

  /// True when the server rejected the call with the existing FORBIDDEN code.
  bool get isForbidden => code == 'FORBIDDEN';
}
