// Replay is only HTTP 403 CSRF_REJECTED.
// The cookie strategy and the interceptor are real. The server is
// FakeApiClient, reached through the Dio transport. No socket.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('403 CSRF_REJECTED refreshes once and replays once', () async {
    final harness = await _open();
    final cookie = await harness.cookies.cookieHeader();
    await harness.fake.serveHttp(
      method: 'GET',
      path: ApiEndpoints.csrf,
      headers: {'Cookie': cookie!},
    );
    harness.transport.calls.clear();

    await harness.layer.client.post(
      ApiEndpoints.changePassword,
      body: const {'currentPassword': 'x', 'newPassword': '0123456789ab'},
    );

    final writes = harness.transport.matching(
      'POST',
      ApiEndpoints.changePassword,
    );
    expect(writes, hasLength(2));
    expect(writes.first.csrf, 'fake-csrf');
    expect(writes.last.csrf, isNot('fake-csrf'));
    expect(harness.transport.matching('GET', ApiEndpoints.csrf), hasLength(1));
    expect(harness.layer.session.state, isA<SessionAuthenticated>());
    expect(await harness.cookies.cookieHeader(), contains('abdo_session'));
  });

  test('a 409 whose message contains CSRF is not refreshed', () async {
    await _expectNoReplay(
      status: 409,
      code: 'VERSION_CONFLICT',
      message: 'missing CSRF token',
    );
  });

  test('a 500 whose message contains CSRF is not refreshed', () async {
    await _expectNoReplay(
      status: 500,
      code: 'SERVER_ERROR',
      message: 'CSRF token mismatch.',
    );
  });

  test('a 403 CSRF_MISSING is not refreshed', () async {
    await _expectNoReplay(
      status: 403,
      code: 'CSRF_MISSING',
      message: 'الرمز غير موجود',
    );
  });

  test('403 PERMISSION_DENIED with CSRF only in the message is not refreshed',
      () async {
    await _expectNoReplay(
      status: 403,
      code: 'PERMISSION_DENIED',
      message: 'CSRF check failed',
    );
  });
}

Future<void> _expectNoReplay({
  required int status,
  required String code,
  required String message,
}) async {
  final harness = await _open();
  harness.fake.failNextResponse = (
    status: status,
    code: code,
    message: message,
  );
  harness.transport.calls.clear();

  final error = await _capture(
    harness.layer.client.post(
      ApiEndpoints.changePassword,
      body: const {'currentPassword': 'x', 'newPassword': '0123456789ab'},
    ),
  );
  expect(isCsrfRejection(error), isFalse);
  expect(
    harness.transport.matching('POST', ApiEndpoints.changePassword),
    hasLength(1),
  );
  expect(harness.transport.matching('GET', ApiEndpoints.csrf), isEmpty);
  expect(harness.layer.session.state, isA<SessionAuthenticated>());
  expect(await harness.cookies.isEmpty(), isFalse);
}

Future<ApiException> _capture(Future<void> call) async {
  try {
    await call;
  } on ApiException catch (error) {
    return error;
  }
  throw StateError('the call succeeded');
}

Future<_Harness> _open() async {
  final cookies = InMemoryCookieStore();
  final fake = FakeApiClient(latency: Duration.zero);
  final transport = _Transport(fake);
  final layer = ApiLayer.create(
    config: const ApiConfig(
      baseUrl: 'https://example.invalid',
      useFakeApi: false,
    ),
    cookieStore: cookies,
    httpClientAdapter: transport,
  );
  addTearDown(layer.dispose);
  await layer.session.login(username: 'admin.demo', password: 'x');
  expect(layer.session.state, isA<SessionAuthenticated>());
  return _Harness(layer, fake, transport, cookies);
}

class _Harness {
  _Harness(this.layer, this.fake, this.transport, this.cookies);
  final ApiLayer layer;
  final FakeApiClient fake;
  final _Transport transport;
  final InMemoryCookieStore cookies;
}

class _Call {
  _Call(this.method, this.path, this.csrf);
  final String method;
  final String path;
  final String? csrf;
}

class _Transport implements HttpClientAdapter {
  _Transport(this.fake);
  final FakeApiClient fake;
  final List<_Call> calls = [];

  List<_Call> matching(String method, String path) => calls
      .where((call) => call.method == method && call.path == path)
      .toList(growable: false);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = <String, String>{};
    options.headers.forEach((key, value) {
      if (value == null) return;
      headers[key] = value is List ? value.join(', ') : '$value';
    });
    final path = options.uri.path.isEmpty ? options.path : options.uri.path;
    String? csrf;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'x-csrf-token') csrf = entry.value;
    }
    calls.add(_Call(options.method.toUpperCase(), path, csrf));
    final query = options.queryParameters.isEmpty
        ? null
        : Map<String, dynamic>.from(options.queryParameters);
    final result = await fake.serveHttp(
      method: options.method,
      path: path,
      data: options.data,
      query: query,
      headers: headers,
      authenticated: options.extra['skipAuth'] != true,
    );
    return ResponseBody.fromString(
      result.body,
      result.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-correlation-id': ['fake'],
        if (result.setCookie.isNotEmpty) 'set-cookie': result.setCookie,
      },
    );
  }
}
