import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/strings.dart';
import 'app_failure.dart';
import 'user_facing_exception.dart';

/// Single mapping from a thrown error to a message the UI may show.
///
/// Logs the diagnostic line only. Server `details`, passwords, cookies, and
/// names are passed through [Redactor] if anything structured is logged later.
class ErrorHandler {
  const ErrorHandler();

  static const _redactor = Redactor();

  AppFailure toFailure(Object error) {
    if (error is ApiException) {
      final message = _message(error);
      return AppFailure(
        message: message,
        code: error.code,
        correlationId: error.correlationId,
      );
    }
    if (error is UserFacingException) {
      return AppFailure(message: error.message, code: 'CLIENT');
    }
    return const AppFailure(
      message: AppStrings.genericError,
      code: 'REQUEST_FAILED',
    );
  }

  /// Top-level server text, plus each validation field the server named.
  /// Field text is already a display string. Raw `details` are not copied.
  static String _message(ApiException error) {
    final message = error.message.trim().isEmpty
        ? AppStrings.genericError
        : error.message.trim();
    if (error is! ValidationException || error.fieldErrors.isEmpty) {
      return message;
    }
    final fields = error.fieldErrors
        .map((field) => field.message.trim())
        .where((text) => text.isNotEmpty && text != message)
        .toList(growable: false);
    if (fields.isEmpty) return message;
    return '$message\n${fields.join('\n')}';
  }

  /// Drops sensitive keys before a value could reach a log.
  Object? redact(Object? value) => _redactor.redact(value);

  void report(Object error, [StackTrace? stackTrace]) {
    // [stackTrace] is accepted so callers can pass it, and intentionally not
    // printed: frames can capture field values.
    debugPrint('api_error ${toFailure(error).diagnostic}');
  }
}

final errorHandlerProvider = Provider<ErrorHandler>(
  (ref) => const ErrorHandler(),
);
