import 'dart:async';

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

/// Redacted diagnostic for one money field the parser refused.
///
/// The line is endpoint, field path, and row id only. The amount, names, and
/// any other payload text are not parameters of this call, so they cannot
/// appear in the line. [sink] replaces [debugPrint] in tests.
class SafeLog {
  static void Function(String? message, {int? wrapWidth})? sink;

  static void invalidMoney({
    required String endpoint,
    required String fieldPath,
    String? rowId,
  }) {
    final row = (rowId == null || rowId.isEmpty) ? '-' : rowId;
    final line =
        '[api] invalid_money endpoint=$endpoint field=$fieldPath row=$row';
    final emit = sink;
    if (emit != null) {
      emit(line);
      return;
    }
    debugPrint(line);
  }
}

final Object _moneyEndpointKey = Object();

/// Endpoint of the response currently being parsed. `'-'` outside a scope.
String get currentMoneyEndpoint {
  final value = Zone.current[_moneyEndpointKey];
  return value is String && value.isNotEmpty ? value : '-';
}

T runWithMoneyEndpoint<T>(String endpoint, T Function() body) {
  return runZoned(body, zoneValues: {_moneyEndpointKey: endpoint});
}
