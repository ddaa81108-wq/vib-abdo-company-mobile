import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/core/config/api_config.dart';
import 'package:flutter_api_layer/core/network/api_client.dart';
import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/core/network/dio_api_client.dart';
import 'package:flutter_api_layer/core/network/get_retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// P7-20. Real [GetRetryInterceptor] and [DioApiClient]. The delay callback
/// is a fake clock: durations are recorded and no wall-clock sleep happens.
void main() {
  test('P7-20 GET connection errors use 400ms then 1200ms', () async {
    final clock = _Clock();
    final adapter = _Script(status: 0, failures: 3);
    final client = _client(adapter, clock);
    await expectLater(
      client.get('/api/health'),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.methods, ['GET', 'GET', 'GET']);
    expect(clock.delays, [
      const Duration(milliseconds: 400),
      const Duration(milliseconds: 1200),
    ]);
  });

  test('P7-20 GET 502, 503, and 504 retry and then stop', () async {
    for (final status in [502, 503, 504]) {
      final clock = _Clock();
      final adapter = _Script(status: status, failures: 1);
      final client = _client(adapter, clock);
      final response = await client.get('/api/health');
      expect(response.statusCode, 200);
      expect(adapter.methods, ['GET', 'GET']);
      expect(clock.delays, [const Duration(milliseconds: 400)]);
    }
  });

  test('P7-20 GET timeouts retry on the same schedule', () async {
    final clock = _Clock();
    final adapter = _Script(
      status: 0,
      failures: 1,
      errorType: DioExceptionType.receiveTimeout,
    );
    final client = _client(adapter, clock);
    final response = await client.get('/api/health');
    expect(response.statusCode, 200);
    expect(clock.delays, [const Duration(milliseconds: 400)]);
  });

  test('P7-20 HEAD is retried and a 503 Retry-After of 2s replaces backoff', () async {
    final clock = _Clock();
    final adapter = _Script(status: 503, failures: 1, retryAfter: '2');
    final dio = _dio(adapter, clock);
    final response = await dio.head<Object>('/api/health');
    expect(response.statusCode, 200);
    expect(adapter.methods, ['HEAD', 'HEAD']);
    expect(clock.delays, [const Duration(seconds: 2)]);
  });

  test('P7-20 Retry-After above 5 seconds is not retried', () async {
    final clock = _Clock();
    final adapter = _Script(status: 503, failures: 1, retryAfter: '6');
    final client = _client(adapter, clock);
    await expectLater(client.get('/api/health'), throwsA(isA<ServerException>()));
    expect(adapter.methods, ['GET']);
    expect(clock.delays, isEmpty);
  });

  test('P7-20 writes are not retried, with or without requestId', () async {
    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      for (final body in <Object?>[
        null,
        {'requestId': 'req-from-caller', 'expectedVersion': 4},
      ]) {
        final clock = _Clock();
        final adapter = _Script(status: 502, failures: 3);
        final dio = _dio(adapter, clock);
        await expectLater(
          dio.request<Object>(
            '/api/customers/c1/transactions',
            data: body == null ? null : jsonEncode(body),
            options: Options(method: method),
          ),
          throwsA(isA<DioException>()),
        );
        expect(adapter.methods, [method], reason: method);
        expect(clock.delays, isEmpty);
      }
    }
  });

  test('P7-20 4xx, 500, 401, and 419 are not retried', () async {
    for (final status in [400, 403, 404, 409, 422, 500, 401, 419]) {
      final clock = _Clock();
      final adapter = _Script(status: status, failures: 3);
      final client = _client(adapter, clock);
      await expectLater(client.get('/api/health'), throwsA(isA<ApiException>()));
      expect(adapter.methods, ['GET'], reason: 'status $status');
      expect(clock.delays, isEmpty, reason: 'status $status');
    }
  });

  test('P7-20 noRetry disables a GET that would otherwise retry', () async {
    final clock = _Clock();
    final adapter = _Script(status: 502, failures: 3);
    final client = _client(adapter, clock);
    await expectLater(
      client.get('/api/health', options: const ApiRequestOptions(noRetry: true)),
      throwsA(isA<ServerException>()),
    );
    expect(adapter.methods, ['GET']);
    expect(clock.delays, isEmpty);
  });
}

DioApiClient _client(_Script adapter, _Clock clock) => DioApiClient(_dio(adapter, clock));

Dio _dio(_Script adapter, _Clock clock) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.invalid',
      headers: const {
        'Accept': 'application/json',
        ApiConfig.clientApiVersionHeader: ApiConfig.clientApiVersion,
      },
    ),
  );
  dio.httpClientAdapter = adapter;
  final retry = GetRetryInterceptor(
    random: _SteadyRandom(),
    delay: clock.delay,
  )..retryDio = dio;
  dio.interceptors.add(retry);
  return dio;
}

class _Clock {
  final List<Duration> delays = [];

  Future<void> delay(Duration duration) async {
    delays.add(duration);
  }
}

class _SteadyRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

class _Script implements HttpClientAdapter {
  _Script({
    required this.status,
    required this.failures,
    this.retryAfter,
    this.errorType = DioExceptionType.connectionError,
  });

  final int status;
  final int failures;
  final String? retryAfter;
  final DioExceptionType errorType;
  final List<String> methods = [];
  int _seen = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method.toUpperCase());
    final attempt = _seen++;
    if (status == 0 && attempt < failures) {
      throw DioException(
        requestOptions: options,
        type: errorType,
        error: 'simulated-offline',
      );
    }
    if (attempt < failures) {
      return ResponseBody.fromString(
        jsonEncode({
          'ok': false,
          'error': {
            'code': status == 401 || status == 419
                ? 'PAGE_EXPIRED'
                : 'UPSTREAM',
            'message': 'x',
            'correlationId': 'c',
          },
        }),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          if (retryAfter != null) 'retry-after': [retryAfter!],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'ok': true,
        'data': {'status': 'ok'},
      }),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}
