import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase7_harness.dart';

/// P7-02. Real [SessionManager], [AuthInterceptor], and [CookieCsrfAuthStrategy].
/// Only the HTTP adapter is fake. Staging role login stays on P7-01's opt-in smoke.
void main() {
  test('P7-02 login succeeds and stores the cookie and CSRF token', () async {
    final harness = await Phase7Harness.open();
    try {
      await harness.login(username: 'admin', password: 'demo-only');
      expect(harness.layer.session.state, isA<SessionAuthenticated>());
      expect(harness.layer.session.currentUser?.id, 'u_1');
      expect(await harness.cookies.isEmpty(), isFalse);
      expect(await harness.cookies.cookieHeader(), contains('phase7-session'));
      final me = harness.transport.matching('GET', ApiEndpoints.me).single;
      expect(me.header('cookie'), contains('phase7-session'));
      expect(me.header('x-csrf-token'), isNull);
    } finally {
      await harness.dispose();
    }
  });

  test('P7-02 wrong credentials stay invalid and do not wipe a session',
      () async {
    final harness = await Phase7Harness.open();
    try {
      harness.transport.loginStatus = 401;
      await expectLater(
        harness.login(password: 'wrong'),
        throwsA(
          isA<InvalidCredentialsException>()
              .having((error) => error.code, 'code', 'INVALID_CREDENTIALS')
              .having((error) => error.statusCode, 'status', 401),
        ),
      );
      expect(harness.layer.session.state, isNot(isA<SessionAuthenticated>()));
      expect(await harness.cookies.isEmpty(), isTrue);

      harness.transport.loginStatus = null;
      await harness.login();
      harness.transport.loginStatus = 401;
      await expectLater(
        harness.login(password: 'wrong'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(harness.layer.session.state, isA<SessionAuthenticated>());
      expect(await harness.cookies.cookieHeader(), contains('phase7-session'));
    } finally {
      await harness.dispose();
    }
  });

  test('P7-02 account lockout follows 423 and 429', () async {
    final locked = await Phase7Harness.open();
    try {
      locked.transport.loginStatus = 423;
      locked.transport.loginCode = 'ACCOUNT_LOCKED';
      locked.transport.loginMessage = 'الحساب مقفل';
      await expectLater(
        locked.login(),
        throwsA(
          isA<AccountLockedException>().having(
            (error) => error.statusCode,
            'status',
            423,
          ),
        ),
      );
      expect(locked.layer.session.state, isNot(isA<SessionAuthenticated>()));
    } finally {
      await locked.dispose();
    }

    final limited = await Phase7Harness.open();
    try {
      limited.transport.loginStatus = 429;
      limited.transport.loginCode = 'RATE_LIMITED';
      limited.transport.loginMessage = 'طلبات كثيرة، حاول لاحقاً';
      limited.transport.loginRetryAfterSeconds = 30;
      await expectLater(
        limited.login(),
        throwsA(
          isA<RateLimitedException>()
              .having((error) => error.statusCode, 'status', 429)
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 30),
              ),
        ),
      );
    } finally {
      await limited.dispose();
    }
  });

  test('P7-02 401 and non-CSRF 419 wipe the session once', () async {
    final harness = await Phase7Harness.open();
    final reasons = <String?>[];
    final sub = harness.layer.session.states.listen((state) {
      if (state is SessionUnauthenticated) reasons.add(state.reason);
    });
    try {
      await harness.login();
      harness.transport.failAuthenticatedStatus = 401;
      final first = harness.layer.client.get(ApiEndpoints.me);
      final second = harness.layer.client.get(ApiEndpoints.health);
      await Future.wait([
        first.then<void>((_) {}, onError: (Object _) {}),
        second.then<void>((_) {}, onError: (Object _) {}),
      ]);
      expect(reasons, ['session_expired']);
      expect(await harness.cookies.isEmpty(), isTrue);
      expect(
        harness.transport.matching('GET', ApiEndpoints.csrf),
        isEmpty,
      );

      reasons.clear();
      harness.transport.failAuthenticatedStatus = null;
      await harness.login();
      harness.transport.failNextStatus = 419;
      harness.transport.failNextCode = 'PAGE_EXPIRED';
      await expectLater(
        harness.layer.client.get(ApiEndpoints.me),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(reasons, ['session_expired']);
      expect(
        harness.transport.matching('GET', ApiEndpoints.csrf),
        isEmpty,
      );
    } finally {
      await sub.cancel();
      await harness.dispose();
    }
  });

  test('P7-02 CSRF mismatch refreshes once and replays once', () async {
    final harness = await Phase7Harness.open();
    try {
      await harness.login();
      final original = harness.transport.csrfToken;
      harness.transport.csrfFailuresRemaining = 1;
      await harness.layer.auth.changePassword(
        currentPassword: 'current-demo',
        newPassword: 'new-password-demo',
      );
      final posts = harness.transport.matching(
        'POST',
        ApiEndpoints.changePassword,
      );
      expect(posts, hasLength(2));
      expect(posts.first.header('x-csrf-token'), original);
      expect(posts.last.header('x-csrf-token'), harness.transport.csrfToken);
      expect(posts.last.header('x-csrf-token'), isNot(original));
      expect(
          harness.transport.matching('GET', ApiEndpoints.csrf), hasLength(1));
      expect(harness.layer.session.state, isA<SessionAuthenticated>());
    } finally {
      await harness.dispose();
    }
  });

  test('P7-02 a second CSRF failure does not loop', () async {
    final harness = await Phase7Harness.open();
    try {
      await harness.login();
      harness.transport.csrfFailuresRemaining = 5;
      await expectLater(
        harness.layer.auth.changePassword(
          currentPassword: 'current-demo',
          newPassword: 'new-password-demo',
        ),
        throwsA(isA<CsrfRejectedException>()),
      );
      expect(
        harness.transport.matching('POST', ApiEndpoints.changePassword),
        hasLength(2),
      );
      expect(
          harness.transport.matching('GET', ApiEndpoints.csrf), hasLength(1));
      expect(harness.layer.session.state, isA<SessionAuthenticated>());
    } finally {
      await harness.dispose();
    }
  });

  test('P7-02 logout calls the server and wipes local session state', () async {
    final harness = await Phase7Harness.open();
    final reasons = <String?>[];
    final sub = harness.layer.session.states.listen((state) {
      if (state is SessionUnauthenticated) reasons.add(state.reason);
    });
    try {
      await harness.login();
      await harness.tokens.saveTokens(
        accessToken: 'access-demo',
        refreshToken: 'refresh-demo',
      );
      await harness.layer.session.logout();
      expect(
        harness.transport.matching('POST', ApiEndpoints.logout),
        hasLength(1),
      );
      final logout =
          harness.transport.matching('POST', ApiEndpoints.logout).single;
      expect(logout.header('cookie'), contains('phase7-session'));
      expect(logout.header('x-csrf-token'), isNotNull);
      expect(await harness.cookies.isEmpty(), isTrue);
      expect(await harness.tokens.readAccessToken(), isNull);
      expect(await harness.tokens.readRefreshToken(), isNull);
      expect(harness.push.deletes, 1);
      expect(harness.cacheClears.value, 1);
      expect(reasons, ['logout']);
    } finally {
      await sub.cancel();
      await harness.dispose();
    }
  });
}
