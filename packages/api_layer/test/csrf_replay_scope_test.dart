// A 419 never refreshes or replays. The cookie strategy and the interceptor
// are real. The server is FakeApiClient, reached through the Dio transport.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a 419 whose code contains CSRF is not replayed', () async {
    await _expectNoReplay(
      status: 419,
      code: 'CSRF_TOKEN_MISMATCH',
      message: 'رمز غير مطابق',
      wipes: false,
    );
  });

  test('a 419 with CSRF only in the message is not replayed', () async {
    await _expectNoReplay(
      status: 419,
      code: 'PAGE_EXPIRED',
      message: 'missing CSRF token',
      wipes: false,
    );
  });

  test('a bare 419 is not replayed and wipes the session once', () async {
    await _expectNoReplay(
      status: 419,
      code: 'PAGE_EXPIRED',
      message: 'انتهت الجلسة',
      wipes: true,
    );
  });
}

Future<void> _expectNoReplay({
  required int status,
  required String code,
  required String message,
  required bool wipes,
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
  expect(harness.transport.calls, hasLength(1));
  expect(
    harness.transport.calls.single.path,
    ApiEndpoints.changePassword,
  );
  expect(harness.transport.matching('GET', ApiEndpoints.csrf), isEmpty);
  if (wipes) {
    expect(error, isA<SessionExpiredException>());
    expect(
      harness.layer.session.state,
      isA<SessionUnauthenticated>().having(
        (state) => state.reason,
        'reason',
        'session_expired',
      ),
    );
    expect(await harness.cookies.isEmpty(), isTrue);
  } else {
    expect(error, isA<CsrfInvalidException>());
    expect(harness.layer.session.state, isA<SessionAuthenticated>());
    expect(await harness.cookies.isEmpty(), isFalse);
  }
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
  _Call(this.method, this.path);
  final String method;
  final String path;
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
    calls.add(_Call(options.method.toUpperCase(), path));
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
