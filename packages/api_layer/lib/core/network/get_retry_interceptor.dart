import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries ONLY GET/HEAD (doc 04 §6). Never retries POST/PUT/PATCH/DELETE.
/// - max 2 retries; delay ~ base * 3^n ± 20% (400ms, 1200ms).
/// - retry on connectionError / timeouts / 502 / 503 / 504.
/// - never on 4xx, 500, badCertificate, cancel.
/// - honours Retry-After on 503 when <= 5s; disabled via extra['noRetry'] = true.
/// Order in the chain: [AuthInterceptor, GetRetryInterceptor, SafeLoggingInterceptor].
/// (Delay arithmetic here is transport timing, not business/money computation.)
class GetRetryInterceptor extends Interceptor {
  GetRetryInterceptor(
      {this.maxRetries = 2,
      this.baseDelay = const Duration(milliseconds: 400),
      Random? random})
      : _random = random ?? Random();

  final int maxRetries;
  final Duration baseDelay;
  final Random _random;

  /// The main Dio (set by ApiStack).
  late Dio retryDio;

  static const _retryStatuses = {502, 503, 504};

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final method = req.method.toUpperCase();
    final attempt = (req.extra['retryAttempt'] as int?) ?? 0;
    if ((method != 'GET' && method != 'HEAD') ||
        req.extra['noRetry'] == true ||
        attempt >= maxRetries ||
        !_isRetryable(err)) {
      return handler.next(err);
    }

    Duration delay = _backoff(attempt);
    if (err.response?.statusCode == 503) {
      final ra = int.tryParse(err.response?.headers.value('retry-after') ?? '');
      if (ra != null) {
        if (ra > 5) return handler.next(err);
        delay = Duration(seconds: ra);
      }
    }

    await Future<void>.delayed(delay);
    if (req.cancelToken?.isCancelled ?? false) return handler.next(err);

    req.extra['retryAttempt'] = attempt + 1;
    try {
      handler.resolve(await retryDio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.badResponse:
        return _retryStatuses.contains(e.response?.statusCode);
      default:
        return false;
    }
  }

  Duration _backoff(int attempt) {
    final ms = baseDelay.inMilliseconds * pow(3, attempt);
    final jitter = 1 + (_random.nextDouble() * 0.4 - 0.2);
    return Duration(milliseconds: (ms * jitter).round());
  }
}
