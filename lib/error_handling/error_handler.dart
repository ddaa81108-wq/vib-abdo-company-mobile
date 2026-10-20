import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/strings.dart';
import 'app_failure.dart';
import 'user_facing_exception.dart';

/// Framework and platform errors go through [ErrorHandler.report] only.
/// The raw exception and stack are not dumped: a frame can hold a field value.
void installErrorHooks(ErrorHandler errors) {
  FlutterError.onError = (details) {
    errors.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errors.report(error, stack);
    return true;
  };
}

/// Single mapping from a thrown error to a message the UI may show.
///
/// The log line is the error code and correlation id, then [Redactor.scrub].
/// The UI message is the server text with bearer tokens, JWTs, and
/// `password=` / `cookie=` assignments removed. Structured `details` are not
/// shown and are not logged.
class ErrorHandler {
  const ErrorHandler();

  static const _redactor = Redactor();

  AppFailure toFailure(Object error) {
    if (error is ApiException) {
      final message = error.message.trim().isEmpty
          ? AppStrings.genericError
          : error.message;
      return AppFailure(
        message: _redactor.scrub(message),
        code: error.code,
        correlationId: error.correlationId,
      );
    }
    if (error is UserFacingException) {
      return AppFailure(
        message: _redactor.scrub(error.message),
        code: 'CLIENT',
      );
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
    debugPrint(_redactor.scrub('api_error ${toFailure(error).diagnostic}'));
  }
}

final errorHandlerProvider = Provider<ErrorHandler>(
  (ref) => const ErrorHandler(),
);
