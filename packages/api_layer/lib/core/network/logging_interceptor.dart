import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../security/redactor.dart';

/// Opt-in logging. The line is method, path, status, correlation id, retry,
/// and duration. Query, userinfo, headers, cookies, and bodies are not
/// included, and the line is still passed through [Redactor.scrub].
class SafeLoggingInterceptor extends Interceptor {
  SafeLoggingInterceptor({this.enabled = false, Redactor? redactor})
    : _redactor = redactor ?? const Redactor();

  final bool enabled;
  final Redactor _redactor;

  /// Path only. Query and fragment stay off the line even if they were glued
  /// onto the path string.
  static String safePath(Uri uri) {
    final path = uri.path;
    final cut = path.indexOf(RegExp(r'[?#]'));
    if (cut < 0) return path;
    return path.substring(0, cut);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_t0'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(
      response.requestOptions,
      response.statusCode,
      response.headers.value('x-correlation-id'),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      err.requestOptions,
      err.response?.statusCode,
      err.response?.headers.value('x-correlation-id'),
      type: err.type.name,
    );
    handler.next(err);
  }

  @visibleForTesting
  String formatLog(
    RequestOptions options,
    int? status,
    String? correlationId, {
    String? type,
  }) {
    final t0 = options.extra['_t0'] as int?;
    final ms = t0 == null
        ? '-'
        : '${DateTime.now().millisecondsSinceEpoch - t0}ms';
    final attempt = options.extra['retryAttempt'] ?? 0;
    return _redactor.scrub(
      '[api] ${options.method} ${safePath(options.uri)} -> ${status ?? type} '
      'cid=${correlationId ?? '-'} try=$attempt $ms',
    );
  }

  void _log(
    RequestOptions options,
    int? status,
    String? correlationId, {
    String? type,
  }) {
    if (!enabled) return;
    debugPrint(formatLog(options, status, correlationId, type: type));
  }
}
