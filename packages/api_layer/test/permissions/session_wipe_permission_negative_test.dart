@Tags(['permissions-negative'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local adapter. These tests never open a socket.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions request) handler;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    seen.add(request);
    return handler(request);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  int status,
  Object body, {
  List<String>? setCookie,
}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (setCookie != null) 'set-cookie': setCookie,
      },
    );

Map<String, Object?> _envelope(int status, String code, String message) => {
      'ok': false,
      'error': {
        'code': code,
        'message': message,
        'correlationId': 'perm-negative',
      },
    };

const _me = {
  'ok': true,
  'data': {
    'user': {
      'id': 'u_12',
      'username': 'employee@example.invalid',
      'displayName': 'موظف',
      'role': 'employee',
      'permissions': ['collections.read', 'collections.write'],
      'mustChangePassword': false,
    },
  },
};

void main() {
  const mapper = ErrorMapper();

  test('authenticated 401 and non-CSRF 419 expire; login 401 does not', () {
    final login = mapper.fromResponse(
      401,
      _envelope(401, 'AUTH_REQUIRED', 'login'),
      null,
      false,
    );
    expect(login, isA<InvalidCredentialsException>());

    final expired = mapper.fromResponse(
      401,
      _envelope(401, 'WHATEVER', 'no'),
    );
    expect(expired, isA<SessionExpiredException>());

    final bare419 = mapper.fromResponse(419, 'not json');
    expect(bare419, isA<SessionExpiredException>());
    expect(bare419.code, 'PAGE_EXPIRED');

    final csrfText = mapper.fromResponse(
      419,
      _envelope(419, 'PAGE_EXPIRED', 'CSRF token missing'),
    );
    expect(csrfText, isA<CsrfInvalidException>());

    final page = mapper.fromResponse(
      403,
      _envelope(403, 'PAGE_EXPIRED', 'gone'),
    );
    expect(page, isA<SessionExpiredException>());
  });

  test('employee cannot decide, reject, or reach management routes on the fake',
      () async {
    final api = _fake();
    await api.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );
    final version = MutationMeta(expectedVersion: 1);

    await expectLater(
      api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: version,
      ),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      api.collections.decide(
        'sb_1',
        CollectionDecision.reject,
        meta: version,
      ),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      api.collections.markCashReceived('sb_2', version),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      api.collections.decideUnlinked(
        'ur_1',
        decision: CollectionDecision.reject,
        meta: version,
      ),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      api.collections.closeDay(batchId: 'b_1', meta: MutationMeta()),
      throwsA(isA<ForbiddenException>()),
    );
    await expectLater(
      api.reports.financialLedger(),
      throwsA(isA<ForbiddenException>()),
    );

    await api.dispose();
  });

  test('logout wipes the cookie jar and the token store, then reads 401',
      () async {
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    await cookies.saveFromSetCookie(['sid=left; Path=/; HttpOnly']);
    await tokens.saveTokens(accessToken: 'access', refreshToken: 'refresh');
    final api = _fake(cookies: cookies, tokens: tokens);

    await api.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );
    await api.session.logout();

    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'logout',
    );
    expect(api.permissions.role, AccountRole.unknown);
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
    await expectLater(
      api.profile.fetchMe(),
      throwsA(isA<SessionExpiredException>()),
    );
    await api.dispose();
  });

  test('a write that expires is not replayed and both stores are wiped',
      () async {
    final writes = <String>[];
    final adapter = _Adapter((request) {
      if (request.path == '/api/auth/login') {
        return _json(200, {
          'ok': true,
          'data': {
            'user': {'username': 'employee@example.invalid'},
            'csrfToken': 't1',
          },
        }, setCookie: [
          'sid=abc; Path=/; HttpOnly'
        ]);
      }
      if (request.path == '/api/me') return _json(200, _me);
      if (request.path == '/api/collections/unlinked-receipts') {
        writes.add('${request.data}');
        return _json(401, _envelope(401, 'AUTH_REQUIRED', 'expired'));
      }
      return _json(401, _envelope(401, 'AUTH_REQUIRED', 'expired'));
    });
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    await tokens.saveTokens(accessToken: 'stale', refreshToken: 'stale-r');
    final api = _real(adapter, cookies: cookies, tokens: tokens);

    await api.session.login(username: 'e', password: 'p');
    await expectLater(
      api.collections.createUnlinkedReceipt(
        customerName: 'n',
        amountUnits: 1,
        meta: MutationMeta(requestId: 'same-request'),
      ),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(writes, hasLength(1));
    expect(writes.single, contains('same-request'));
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
    expect(
      adapter.seen.where((r) => r.path.endsWith('/unlinked-receipts')),
      hasLength(1),
    );
    await api.dispose();
  });

  test('bare 419 logs out and does not replay the write', () async {
    var writes = 0;
    final adapter = _Adapter((request) {
      if (request.path == '/api/auth/login') {
        return _json(200, {
          'ok': true,
          'data': {
            'csrfToken': 't1',
            'user': {'username': 'e'}
          },
        }, setCookie: [
          'sid=abc; Path=/'
        ]);
      }
      if (request.path == '/api/me') return _json(200, _me);
      writes++;
      return _json(419, 'page expired');
    });
    final api = _real(adapter);

    await api.session.login(username: 'e', password: 'p');
    await expectLater(
      api.collections.createUnlinkedReceipt(
        customerName: 'n',
        amountUnits: 1,
        meta: MutationMeta(),
      ),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(writes, 1);
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    await api.dispose();
  });

  test('login 401 keeps stored credentials and does not force logout',
      () async {
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    await cookies.saveFromSetCookie(['sid=keep; Path=/']);
    await tokens.saveTokens(accessToken: 'keep-a', refreshToken: 'keep-r');
    final adapter = _Adapter(
      (request) => _json(401, _envelope(401, 'AUTH_REQUIRED', 'no')),
    );
    final api = _real(adapter, cookies: cookies, tokens: tokens);

    await expectLater(
      api.session.login(username: 'e', password: 'bad'),
      throwsA(isA<InvalidCredentialsException>()),
    );
    expect(await cookies.cookieHeader(), 'sid=keep');
    expect(await tokens.readAccessToken(), 'keep-a');
    expect(api.session.state, isA<SessionUnknown>());
    await api.dispose();
  });

  test('a 419 whose message says CSRF is refreshed once and not logged out',
      () async {
    var writes = 0;
    var csrfReads = 0;
    final adapter = _Adapter((request) {
      if (request.path == '/api/auth/login') {
        return _json(200, {
          'ok': true,
          'data': {
            'csrfToken': 't1',
            'user': {'username': 'e'}
          },
        }, setCookie: [
          'sid=abc; Path=/'
        ]);
      }
      if (request.path == '/api/me') return _json(200, _me);
      if (request.path == '/api/auth/csrf') {
        csrfReads++;
        return _json(200, {
          'ok': true,
          'data': {'csrfToken': 't2'},
        });
      }
      writes++;
      if (request.headers['X-CSRF-Token'] == 't1') {
        return _json(
          419,
          _envelope(419, 'PAGE_EXPIRED', 'CSRF token missing'),
        );
      }
      return _json(200, {
        'ok': true,
        'data': {'id': 'ur_new', 'version': 1},
      });
    });
    final api = _real(adapter);

    await api.session.login(username: 'e', password: 'p');
    final ack = await api.collections.createUnlinkedReceipt(
      customerName: 'n',
      amountUnits: 1,
      meta: MutationMeta(requestId: 'csrf-retry'),
    );
    expect(ack.id, 'ur_new');
    expect(writes, 2);
    expect(csrfReads, 1);
    expect(api.session.state, isA<SessionAuthenticated>());
    await api.dispose();
  });
}

ApiLayer _fake({
  CookieStore? cookies,
  TokenStorage? tokens,
}) =>
    ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      cookieStore: cookies,
      tokenStorage: tokens,
      fakeLatency: Duration.zero,
    );

ApiLayer _real(
  _Adapter adapter, {
  CookieStore? cookies,
  TokenStorage? tokens,
}) =>
    ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://staging.example.invalid',
        useFakeApi: false,
      ),
      cookieStore: cookies ?? InMemoryCookieStore(),
      tokenStorage: tokens ?? InMemoryTokenStorage(),
      httpClientAdapter: adapter,
    );
