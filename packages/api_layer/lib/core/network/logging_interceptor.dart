import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only, redacted logging. NEVER logs headers, cookies, CSRF tokens, bodies,
/// amounts or names. Logs: method, path (no query), status, x-correlation-id,
/// retry attempt, duration.
class SafeLoggingInterceptor extends Interceptor {
  SafeLoggingInterceptor({this.enabled = kDebugMode});
  final bool enabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_t0'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, response.statusCode,
        response.headers.value('x-correlation-id'));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, err.response?.statusCode,
        err.response?.headers.value('x-correlation-id'),
        type: err.type.name);
    handler.next(err);
  }

  void _log(RequestOptions o, int? status, String? correlationId,
      {String? type}) {
    if (!enabled) return;
    final t0 = o.extra['_t0'] as int?;
    final ms =
        t0 == null ? '-' : '${DateTime.now().millisecondsSinceEpoch - t0}ms';
    final attempt = o.extra['retryAttempt'] ?? 0;
    debugPrint(
        '[api] ${o.method} ${o.uri.path} -> ${status ?? type} cid=${correlationId ?? '-'} try=$attempt $ms');
  }
}
