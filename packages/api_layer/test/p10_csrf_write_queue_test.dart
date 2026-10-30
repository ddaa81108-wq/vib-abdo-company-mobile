import 'dart:async';
import 'dart:convert';
import 'dart:io' show Cookie;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// P-10. Real [CookieCsrfAuthStrategy] and [DioApiClient]. Only the HTTP
/// adapter is fake. Nothing here opens a socket or calls staging.
void main() {
  test('abdo_session survives SameSite and is wiped from the secure store',
      () async {
    const session = '${ApiConfig.sessionCookieName}=sess-1; Path=/; HttpOnly; '
        'Secure; SameSite=Strict; Max-Age=43200';
    const clearedMfa =
        'abdo_mfa=clear-me; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0';
    final backing = <String, String>{};
    final first = SecureCookieStore.memory(backing);
    await first.saveFromSetCookie([session, clearedMfa]);
    expect(await first.cookieHeader(), '${ApiConfig.sessionCookieName}=sess-1');
    expect(await first.cookieHeader(), isNot(contains('abdo_mfa=')));

    final second = SecureCookieStore.memory(backing);
    expect(
      await second.cookieHeader(),
      '${ApiConfig.sessionCookieName}=sess-1',
    );
    await second.clear();
    final third = SecureCookieStore.memory(backing);
    expect(await third.isEmpty(), isTrue);

    final expiredOnly = InMemoryCookieStore();
    await expiredOnly.saveFromSetCookie([
      '${ApiConfig.sessionCookieName}=old; Path=/; Expires=Wed, 21 Oct 2015 07:28:00 GMT; HttpOnly; Secure; SameSite=Strict',
    ]);
    expect(await expiredOnly.isEmpty(), isTrue);

    final memory = InMemoryCookieStore();
    await memory.saveFromSetCookie([
      '${ApiConfig.sessionCookieName}=old; Path=/; Expires=Wed, 21 Oct 2015 07:28:00 GMT; HttpOnly; Secure; SameSite=Strict',
      session,
      clearedMfa,
    ]);
    expect(
        await memory.cookieHeader(), '${ApiConfig.sessionCookieName}=sess-1');
    await memory.clear();
    expect(await memory.isEmpty(), isTrue);
  });

  test('two writes with an expired token share one CSRF fetch and do not loop',
      () async {
    final harness = await _Harness.open();
    addTearDown(harness.dispose);
    await harness.login();
    harness.adapter.accepted = 'expired-not-issued';
    final gate = Completer<void>();
    harness.adapter.blockFirstWrite = gate;

    final first = harness.layer.client.post(
      '/api/work',
      body: const {'requestId': 'write-a'},
    );
    try {
      await _until(() => harness.adapter.writes.length == 1);

      final read = harness.layer.client.get(ApiEndpoints.me);
      expect((await read.timeout(const Duration(seconds: 2))).statusCode, 200);
      expect(harness.adapter.writes, hasLength(1));

      final second = harness.layer.client.post(
        '/api/work',
        body: const {'requestId': 'write-b'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(harness.adapter.writes, hasLength(1));
      expect(harness.adapter.csrfFetches, 0);

      if (!gate.isCompleted) gate.complete();
      final results = await Future.wait([first, second]);
      expect(results, hasLength(2));
      expect(harness.adapter.csrfFetches, 1);
      expect(harness.adapter.writes, hasLength(3));
      expect(harness.adapter.writes[0].csrf, 't-login');
      expect(harness.adapter.writes[1].csrf, 't-1');
      expect(harness.adapter.writes[2].csrf, 't-1');
      expect(harness.layer.session.state, isA<SessionAuthenticated>());

      final csrf = harness.adapter.calls
          .where((call) => call.path == ApiEndpoints.csrf)
          .single;
      expect(csrf.version, ApiConfig.clientApiVersion);
      expect(csrf.csrf, isNull);
      expect(csrf.cookie, contains('${ApiConfig.sessionCookieName}='));
      for (final call in harness.adapter.calls) {
        expect(
          call.version,
          ApiConfig.clientApiVersion,
          reason: '${call.method} ${call.path}',
        );
      }
      expect(
        harness.adapter.calls.where((call) => call.method == 'GET'),
        isNotEmpty,
      );
      expect(harness.adapter.writes, isNotEmpty);
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  });

  test('a main-client CSRF GET takes the write mutex and shares one refresh',
      () async {
    final harness = await _Harness.open();
    addTearDown(harness.dispose);
    await harness.login();
    final gate = Completer<void>();
    harness.adapter.blockFirstWrite = gate;
    final write = harness.layer.client.post(
      '/api/work',
      body: const {'requestId': 'hold-for-csrf'},
    );
    try {
      await _until(() => harness.adapter.writes.length == 1);
      final rotation = harness.layer.client.get(ApiEndpoints.csrf);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(harness.adapter.csrfFetches, 0);
      expect(harness.adapter.writes, hasLength(1));

      if (!gate.isCompleted) gate.complete();
      final rotated = await rotation.timeout(const Duration(seconds: 2));
      await write;
      expect(harness.adapter.csrfFetches, 1);
      expect(rotated.dataMap['csrfToken'], 't-1');
      expect(harness.adapter.writes.single.csrf, 't-login');

      await harness.layer.client.post(
        '/api/work',
        body: const {'requestId': 'after-queued-csrf'},
      );
      expect(harness.adapter.csrfFetches, 1);
      expect(harness.adapter.writes.last.csrf, 't-1');
    } finally {
      if (!gate.isCompleted) gate.complete();
    }

    final pause = Completer<void>();
    harness.adapter.blockNextCsrf = pause;
    final first = harness.layer.client.get(ApiEndpoints.csrf);
    try {
      await _until(() => harness.adapter.csrfFetches == 2);
      final second = harness.layer.client.get(ApiEndpoints.csrf);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(harness.adapter.csrfFetches, 2);
      if (!pause.isCompleted) pause.complete();
      final both = await Future.wait([first, second]);
      expect(harness.adapter.csrfFetches, 2);
      expect(both[0].dataMap['csrfToken'], 't-2');
      expect(both[1].dataMap['csrfToken'], 't-2');
    } finally {
      if (!pause.isCompleted) pause.complete();
    }
  });

  test('a write after CSRF rotation sends the new token once', () async {
    final harness = await _Harness.open();
    addTearDown(harness.dispose);
    await harness.login();
    final before = harness.adapter.accepted;
    final rotated = await harness.layer.client.get(ApiEndpoints.csrf);
    final token = rotated.dataMap['csrfToken'];
    expect(token, isNot(before));
    expect(harness.adapter.csrfFetches, 1);

    await harness.layer.client.post(
      '/api/work',
      body: const {'requestId': 'after-rotate'},
    );
    expect(harness.adapter.csrfFetches, 1);
    expect(harness.adapter.writes, hasLength(1));
    expect(harness.adapter.writes.single.csrf, token);
    expect(harness.adapter.writes.single.version, ApiConfig.clientApiVersion);
    final me = harness.adapter.calls
        .where((call) => call.method == 'GET' && call.path == ApiEndpoints.me)
        .last;
    expect(me.version, ApiConfig.clientApiVersion);
    expect(me.csrf, isNull);
  });

  test(
      '403 CSRF_REJECTED refreshes once; a 419 CSRF_REJECTED does not; a non-CSRF 419 wipes once',
      () async {
    final harness = await _Harness.open();
    addTearDown(harness.dispose);
    await harness.login();
    harness.adapter.rejectionsLeft = 5;
    harness.adapter.rejectionStatus = 403;
    await expectLater(
      harness.layer.client.post(
        '/api/work',
        body: const {'requestId': 'reject-403'},
      ),
      throwsA(
        isA<CsrfInvalidException>()
            .having((error) => error.code, 'code', 'CSRF_REJECTED')
            .having((error) => error.statusCode, 'status', 403),
      ),
    );
    expect(harness.adapter.csrfFetches, 1);
    expect(harness.adapter.writes, hasLength(2));
    expect(harness.layer.session.state, isA<SessionAuthenticated>());
    expect(await harness.cookies.isEmpty(), isFalse);

    harness.adapter.rejectionsLeft = 1;
    harness.adapter.rejectionStatus = 419;
    harness.adapter.writes.clear();
    final csrfBefore = harness.adapter.csrfFetches;
    await expectLater(
      harness.layer.client.post(
        '/api/work',
        body: const {'requestId': 'reject-419'},
      ),
      throwsA(
        isA<CsrfRejectedException>()
            .having((error) => error.statusCode, 'status', 419)
            .having((error) => isCsrfRejection(error), 'replay', isFalse),
      ),
    );
    expect(harness.adapter.csrfFetches, csrfBefore);
    expect(harness.adapter.writes, hasLength(1));
    expect(harness.layer.session.state, isA<SessionAuthenticated>());

    harness.adapter.failNext = (status: 419, code: 'PAGE_EXPIRED');
    final csrfAtWipe = harness.adapter.csrfFetches;
    await expectLater(
      harness.layer.client.get(ApiEndpoints.me),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(harness.adapter.csrfFetches, csrfAtWipe);
    expect(await harness.cookies.isEmpty(), isTrue);
    expect(
      harness.layer.session.state,
      isA<SessionUnauthenticated>().having(
        (state) => state.reason,
        'reason',
        'session_expired',
      ),
    );
  });

  test('logout and a 401 wipe clear abdo_session', () async {
    final harness = await _Harness.open(secure: true);
    addTearDown(harness.dispose);
    await harness.login();
    expect(
      await harness.cookies.cookieHeader(),
      '${ApiConfig.sessionCookieName}=sess-1',
    );
    final persisted = SecureCookieStore.memory(harness.backing);
    expect(
      await persisted.cookieHeader(),
      '${ApiConfig.sessionCookieName}=sess-1',
    );

    await harness.layer.session.logout();
    expect(await harness.cookies.isEmpty(), isTrue);
    expect(await SecureCookieStore.memory(harness.backing).isEmpty(), isTrue);
    expect(
      harness.layer.session.state,
      isA<SessionUnauthenticated>().having(
        (state) => state.reason,
        'reason',
        'logout',
      ),
    );

    await harness.login();
    expect(await harness.cookies.isEmpty(), isFalse);
    harness.adapter.failNext = (status: 401, code: 'AUTH_REQUIRED');
    final first = harness.layer.client.get(ApiEndpoints.me);
    final second = harness.layer.client.get(ApiEndpoints.health);
    await Future.wait([
      first.then<void>((_) {}, onError: (Object _) {}),
      second.then<void>((_) {}, onError: (Object _) {}),
    ]);
    expect(await harness.cookies.isEmpty(), isTrue);
    expect(
      harness.layer.session.state,
      isA<SessionUnauthenticated>().having(
        (state) => state.reason,
        'reason',
        'session_expired',
      ),
    );
    expect(harness.adapter.csrfFetches, 0);
  });

  test('fake HTTP contract rotates CSRF and can reject a missing version',
      () async {
    final fake = FakeApiClient(latency: Duration.zero);
    final login = await fake.serveHttp(
      method: 'POST',
      path: ApiEndpoints.login,
      data: {'username': 'admin.demo', 'password': 'x'},
      headers: const {
        ApiConfig.clientApiVersionHeader: ApiConfig.clientApiVersion,
      },
      authenticated: false,
    );
    expect(login.status, 200);
    expect(login.setCookie.single, contains('${ApiConfig.sessionCookieName}='));
    final loginBody = jsonDecode(login.body) as Map<String, dynamic>;
    final token = (loginBody['data'] as Map)['csrfToken'];
    expect(token, 'fake-csrf');
    final cookie = _cookiePair(login.setCookie.single);

    final read = await fake.serveHttp(
      method: 'GET',
      path: ApiEndpoints.me,
      headers: {'Cookie': cookie},
    );
    expect(read.status, 200);

    final missingVersion = await fake.serveHttp(
      method: 'POST',
      path: ApiEndpoints.logout,
      headers: {
        'Cookie': cookie,
        'X-CSRF-Token': '$token',
      },
    );
    expect(missingVersion.status, 409);
    final missingBody = jsonDecode(missingVersion.body) as Map<String, dynamic>;
    expect((missingBody['error'] as Map)['code'], 'CLIENT_VERSION_MISMATCH');

    final rotated = await fake.serveHttp(
      method: 'GET',
      path: ApiEndpoints.csrf,
      headers: {
        'Cookie': cookie,
        ApiConfig.clientApiVersionHeader: ApiConfig.clientApiVersion,
      },
    );
    expect(rotated.status, 200);
    final next = (jsonDecode(rotated.body) as Map)['data']['csrfToken'];
    expect(next, isNot(token));

    final stale = await fake.serveHttp(
      method: 'POST',
      path: ApiEndpoints.logout,
      headers: {
        'Cookie': cookie,
        'X-CSRF-Token': '$token',
        ApiConfig.clientApiVersionHeader: ApiConfig.clientApiVersion,
      },
    );
    expect(stale.status, 403);
    expect(
      ((jsonDecode(stale.body) as Map)['error'] as Map)['code'],
      'CSRF_REJECTED',
    );

    final fresh = await fake.serveHttp(
      method: 'POST',
      path: ApiEndpoints.logout,
      headers: {
        'Cookie': cookie,
        'X-CSRF-Token': '$next',
        ApiConfig.clientApiVersionHeader: ApiConfig.clientApiVersion,
      },
    );
    expect(fresh.status, 200);
  });

  test('fake stack stores abdo_session and uses the rotated token', () async {
    final cookies = InMemoryCookieStore();
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      cookieStore: cookies,
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);
    await layer.session.login(username: 'admin.demo', password: 'x');
    expect(
      await cookies.cookieHeader(),
      startsWith('${ApiConfig.sessionCookieName}='),
    );

    final fake = layer.client as FakeApiClient;
    await layer.client.post(
      '/api/customers/c_55/transactions',
      body: const {
        'requestId': 'csrf-check',
        'expectedVersion': 4,
        'type': 'payment',
        'paymentMode': 'full',
      },
    );
    expect(_header(fake, ApiConfig.clientApiVersionHeader), '1');
    expect(_header(fake, 'x-csrf-token'), 'fake-csrf');
    expect(
      _header(fake, 'cookie'),
      contains('${ApiConfig.sessionCookieName}='),
    );

    final rotated = await layer.client.get(ApiEndpoints.csrf);
    final token = rotated.dataMap['csrfToken'];
    expect(token, isNot('fake-csrf'));
    await layer.session.logout();
    expect(_header(fake, 'x-csrf-token'), token);
    expect(_header(fake, ApiConfig.clientApiVersionHeader), '1');
    expect(await cookies.isEmpty(), isTrue);
  });
}

Future<void> _until(bool Function() done) async {
  final watch = Stopwatch()..start();
  while (!done()) {
    if (watch.elapsed > const Duration(seconds: 2)) {
      fail('timed out waiting for the queued write');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

String _cookiePair(String setCookie) {
  final cookie = Cookie.fromSetCookieValue(setCookie);
  return '${cookie.name}=${cookie.value}';
}

String? _header(FakeApiClient fake, String name) {
  for (final entry in fake.lastRequestHeaders.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

const _user = {
  'id': 'u_1',
  'username': 'admin@example.invalid',
  'displayName': 'مدير تجريبي',
  'role': 'admin',
  'permissions': <String>[],
  'mustChangePassword': false,
};

class _Harness {
  _Harness({
    required this.layer,
    required this.adapter,
    required this.cookies,
    required this.backing,
  });

  final ApiLayer layer;
  final _Adapter adapter;
  final CookieStore cookies;
  final Map<String, String>? backing;

  static Future<_Harness> open({bool secure = false}) async {
    final adapter = _Adapter();
    final backing = secure ? <String, String>{} : null;
    final cookies =
        secure ? SecureCookieStore.memory(backing) : InMemoryCookieStore();
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://api.example.invalid',
        useFakeApi: false,
      ),
      cookieStore: cookies,
      httpClientAdapter: adapter,
    );
    return _Harness(
      layer: layer,
      adapter: adapter,
      cookies: cookies,
      backing: backing,
    );
  }

  Future<void> login() {
    return layer.session.login(username: 'admin', password: 'demo-only');
  }

  Future<void> dispose() => layer.dispose();
}

class _Call {
  _Call(this.method, this.path, this.csrf, this.version, this.cookie);
  final String method;
  final String path;
  final String? csrf;
  final String? version;
  final String? cookie;
}

class _Adapter implements HttpClientAdapter {
  final List<_Call> calls = [];
  final List<_Call> writes = [];
  String accepted = 't-login';
  int csrfFetches = 0;
  int rejectionsLeft = 0;
  int rejectionStatus = 403;
  ({int status, String code})? failNext;
  Completer<void>? blockFirstWrite;
  bool _blocked = false;
  Completer<void>? blockNextCsrf;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.isEmpty ? options.path : options.uri.path;
    final method = options.method.toUpperCase();
    final call = _Call(
      method,
      path,
      _headerOf(options, 'X-CSRF-Token'),
      _headerOf(options, ApiConfig.clientApiVersionHeader),
      _headerOf(options, 'Cookie'),
    );
    calls.add(call);
    final unsafe = method != 'GET' && method != 'HEAD';
    if (unsafe && path != ApiEndpoints.login) writes.add(call);

    if (path == ApiEndpoints.login) {
      accepted = 't-login';
      return _ok(
        {'user': _user, 'csrfToken': accepted},
        setCookie: [
          '${ApiConfig.sessionCookieName}=sess-1; Path=/; HttpOnly; Secure; SameSite=Strict',
        ],
      );
    }
    if (path == ApiEndpoints.csrf) {
      csrfFetches++;
      final pause = blockNextCsrf;
      blockNextCsrf = null;
      if (pause != null) await pause.future;
      accepted = 't-$csrfFetches';
      return _ok({'csrfToken': accepted});
    }
    if (unsafe && blockFirstWrite != null && !_blocked) {
      _blocked = true;
      await blockFirstWrite!.future;
    }
    if (unsafe && path != ApiEndpoints.login && rejectionsLeft > 0) {
      rejectionsLeft--;
      return _fail(rejectionStatus, 'CSRF_REJECTED', 'تم رفض طلب الحماية.');
    }
    final forced = failNext;
    if (forced != null) {
      failNext = null;
      return _fail(forced.status, forced.code, 'يجب تسجيل الدخول أولًا.');
    }
    if (unsafe && call.csrf != accepted) {
      return _fail(403, 'CSRF_REJECTED', 'تم رفض طلب الحماية.');
    }
    if (path == ApiEndpoints.me) return _ok({'user': _user});
    return _ok(const {'ok': true});
  }

  String? _headerOf(RequestOptions options, String name) {
    final value = options.headers[name];
    if (value == null) return null;
    final text = value is List ? value.join(', ') : '$value';
    return text.isEmpty ? null : text;
  }
}

ResponseBody _ok(Object? data, {List<String>? setCookie}) =>
    ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );

ResponseBody _fail(int status, String code, String message) =>
    ResponseBody.fromString(
      jsonEncode({
        'ok': false,
        'error': {
          'code': code,
          'message': message,
          'correlationId': 'corr-$status',
        },
      }),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
