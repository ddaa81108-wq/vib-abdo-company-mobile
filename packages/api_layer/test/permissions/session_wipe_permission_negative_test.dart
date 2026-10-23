@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/error_mapper.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _envelope(String code, String message) => {
      'ok': false,
      'error': {
        'code': code,
        'message': message,
        'correlationId': 'perm-negative',
      },
    };

void main() {
  const mapper = ErrorMapper();

  test('authenticated 401 and non-CSRF 419 expire; login 401 does not', () {
    final login = mapper.fromResponse(
      401,
      _envelope('AUTH_REQUIRED', 'login'),
      null,
      false,
    );
    expect(login, isA<InvalidCredentialsException>());
    expect(login.code, 'AUTH_REQUIRED');

    // PR #38: after login, any 401 is expiry, including a credentials-shaped code.
    final credentials = mapper.fromResponse(
      401,
      _envelope('INVALID_CREDENTIALS', 'no'),
    );
    expect(credentials, isA<SessionExpiredException>());

    final expired = mapper.fromResponse(
      401,
      _envelope('WHATEVER', 'no'),
    );
    expect(expired, isA<SessionExpiredException>());

    final bare419 = mapper.fromResponse(419, 'not json');
    expect(bare419, isA<SessionExpiredException>());
    expect(bare419.code, 'PAGE_EXPIRED');

    final csrfText = mapper.fromResponse(
      419,
      _envelope('PAGE_EXPIRED', 'CSRF token missing'),
    );
    expect(csrfText, isA<SessionExpiredException>());

    final page = mapper.fromResponse(
      403,
      _envelope('PAGE_EXPIRED', 'gone'),
    );
    expect(page, isA<SessionExpiredException>());
  });

  test(
    'employee cannot decide, reject, or reach management routes on the fake',
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
    },
  );

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

  test('a bad login does not wipe a cookie or token that was already stored',
      () async {
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    await cookies.saveFromSetCookie(['sid=keep; Path=/']);
    await tokens.saveTokens(accessToken: 'keep-a', refreshToken: 'keep-r');
    final api = _fake(cookies: cookies, tokens: tokens);

    await expectLater(
      api.session.login(username: 'e', password: 'wrong'),
      throwsA(isA<InvalidCredentialsException>()),
    );
    expect(await cookies.cookieHeader(), contains('sid=keep'));
    expect(await tokens.readAccessToken(), 'keep-a');
    expect(api.session.state, isA<SessionUnknown>());
    await api.dispose();
  });

  test('expiring the fake session wipes both stores and does not replay',
      () async {
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    await tokens.saveTokens(accessToken: 'stale', refreshToken: 'stale-r');
    final api = _fake(cookies: cookies, tokens: tokens);
    await api.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );
    final fake = api.client as FakeApiClient;
    fake.expireSession();

    await expectLater(
      api.collections.createUnlinkedReceipt(
        customerName: 'n',
        amountUnits: 1,
        meta: MutationMeta(requestId: 'same-request'),
      ),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(fake.mutationRequestIds, isEmpty);
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
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
