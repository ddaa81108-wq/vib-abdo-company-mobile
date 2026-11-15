import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase7/phase7_harness.dart' show Phase7Transport;

const _config = ApiConfig(
  baseUrl: 'https://session.example.invalid',
  useFakeApi: false,
);

void main() {
  test(
    'a new login waits for logout cleanup and then publishes its profile',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final transport = Phase7Transport();
      final api = ApiLayer.create(
        config: _config,
        cookieStore: SecureCookieStore.memory(),
        httpClientAdapter: transport,
        cleanups: [
          () async {
            entered.complete();
            await release.future;
          },
        ],
      );
      addTearDown(api.dispose);
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      await api.session.login(username: 'admin', password: 'test-only');
      final logout = api.session.logout();
      expect(identical(logout, api.session.logout()), isTrue);
      await entered.future;
      expect(api.session.state, isA<SessionAuthenticated>());
      expect(api.session.signingOut, isTrue);
      final login = api.session.login(username: 'admin', password: 'test-only');
      await Future<void>.delayed(Duration.zero);
      expect(transport.matching('POST', ApiEndpoints.login), hasLength(1));
      release.complete();
      await Future.wait([logout, login]).timeout(const Duration(seconds: 2));
      expect(api.session.state, isA<SessionAuthenticated>());
      expect(api.session.signingOut, isFalse);
      expect(transport.matching('POST', ApiEndpoints.login), hasLength(2));
      expect(transport.matching('POST', ApiEndpoints.logout), hasLength(1));
    },
  );

  for (final offline in [false, true]) {
    test(
      'restart after ${offline ? 'offline' : 'normal'} logout restores no session',
      () async {
        final backing = <String, String>{};
        final tokens = InMemoryTokenStorage();
        final transport = Phase7Transport();
        final api = ApiLayer.create(
          config: _config,
          cookieStore: SecureCookieStore.memory(backing),
          tokenStorage: tokens,
          httpClientAdapter: transport,
        );
        addTearDown(api.dispose);
        await api.session.login(username: 'admin', password: 'test-only');
        await tokens.saveTokens(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
        );
        if (offline) transport.connectionErrorsRemaining = 1;
        await api.session.logout().timeout(const Duration(seconds: 2));
        expect(api.session.state, isA<SessionUnauthenticated>());
        expect(backing, isEmpty);
        expect(await tokens.readAccessToken(), isNull);
        expect(await tokens.readRefreshToken(), isNull);
        final restartTransport = Phase7Transport();
        final restarted = ApiLayer.create(
          config: _config,
          cookieStore: SecureCookieStore.memory(backing),
          tokenStorage: tokens,
          httpClientAdapter: restartTransport,
        );
        addTearDown(restarted.dispose);
        await restarted.session.restore();
        expect(restarted.session.state, isA<SessionUnauthenticated>());
        expect(restartTransport.matching('GET', ApiEndpoints.me), isEmpty);
      },
    );
  }

  test(
    'a cleanup 401 cannot make the wipe await itself or lock the next login',
    () async {
      final transport = Phase7Transport();
      late ApiLayer api;
      api = ApiLayer.create(
        config: _config,
        cookieStore: SecureCookieStore.memory(),
        httpClientAdapter: transport,
        cleanups: [
          () async {
            transport.failAuthenticatedStatus = 401;
            try {
              await api.client.get(ApiEndpoints.me);
            } on SessionExpiredException {
              // The cleanup must observe the 401 without waiting on itself.
            } finally {
              transport.failAuthenticatedStatus = null;
            }
          },
        ],
      );
      addTearDown(api.dispose);
      await api.session.login(username: 'admin', password: 'test-only');
      await api.session.logout().timeout(const Duration(seconds: 2));
      expect(api.session.state, isA<SessionUnauthenticated>());
      await api.session
          .login(username: 'admin', password: 'test-only')
          .timeout(const Duration(seconds: 2));
      expect(api.session.state, isA<SessionAuthenticated>());
    },
  );

  test(
    'a failed credential delete is reported and logout can be retried',
    () async {
      final tokens = _FailingTokens();
      final api = ApiLayer.create(
        config: _config,
        cookieStore: SecureCookieStore.memory(),
        tokenStorage: tokens,
        httpClientAdapter: Phase7Transport(),
      );
      addTearDown(api.dispose);
      await api.session.login(username: 'admin', password: 'test-only');
      await tokens.saveTokens(accessToken: 'test', refreshToken: 'test');
      await expectLater(api.session.logout(), throwsStateError);
      expect(api.session.signingOut, isFalse);
      expect(api.session.state, isA<SessionAuthenticated>());
      tokens.failClear = false;
      await api.session.logout().timeout(const Duration(seconds: 2));
      expect(api.session.state, isA<SessionUnauthenticated>());
      expect(await tokens.readAccessToken(), isNull);
    },
  );
}

class _FailingTokens extends InMemoryTokenStorage {
  bool failClear = true;

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('simulated storage failure');
    await super.clear();
  }
}
