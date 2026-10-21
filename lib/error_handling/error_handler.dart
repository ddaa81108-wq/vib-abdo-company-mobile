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
      final message = error.message.trim().isEmpty
          ? AppStrings.genericError
          : error.message;
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

  /// Drops sensitive keys before a value could reach a log.
  Object? redact(Object? value) => _redactor.redact(value);

  void report(Object error, [StackTrace? stackTrace]) {
    // [stackTrace] is accepted so callers can pass it, and intentionally not
    // printed: frames can capture field values.
    debugPrint('api_error ${toFailure(error).diagnostic}');
  }
}

/// Riverpod retry for provider failures.
///
/// A FORBIDDEN result is not retried. Every other error keeps
/// [ProviderContainer.defaultRetry].
Duration? retryUnlessForbidden(int retryCount, Object error) {
  if (const ErrorHandler().toFailure(error).isForbidden) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

final errorHandlerProvider = Provider<ErrorHandler>(
  (ref) => const ErrorHandler(),
);
