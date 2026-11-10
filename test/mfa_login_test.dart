import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/login/mfa_screen.dart';

import 'support/pump_app.dart';

void main() {
  test(
    'a challenge is not a session and only a valid code loads /api/me',
    () async {
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
      );
      addTearDown(layer.dispose);
      await layer.session.login(username: 'mfa.admin', password: 'demo-only');
      expect(layer.session.state, isA<SessionOtpRequired>());
      expect(layer.session.currentUser, isNull);
      expect(layer.permissions.role, AccountRole.unknown);
      expect(
        captureWindowIsSecure(debuggable: false, state: layer.session.state),
        isTrue,
      );
      expect(
        captureWindowIsSecure(debuggable: true, state: layer.session.state),
        isFalse,
      );

      await expectLater(
        layer.session.verifyMfa('111111'),
        throwsA(isA<MfaInvalidException>()),
      );
      expect(layer.session.state, isA<SessionOtpRequired>());
      expect(
        '${layer.session.state}',
        isNot(contains(FakeFixtures.mfaFixtureCode)),
      );

      await layer.session.verifyMfa(FakeFixtures.mfaFixtureCode);
      expect(layer.session.state, isA<SessionAuthenticated>());
      expect(layer.session.currentUser!.isOwner, isTrue);
      expect(layer.session.currentUser!.role, 'admin');
      expect(layer.permissions.fullAccess, isTrue);
    },
  );

  test('an expired challenge does not become a session', () async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(layer.dispose);
    await layer.session.login(username: 'mfa.admin', password: 'demo-only');
    (layer.client as FakeApiClient).expireMfaChallenges();
    await expectLater(
      layer.session.verifyMfa(FakeFixtures.mfaFixtureCode),
      throwsA(isA<MfaInvalidException>()),
    );
    expect(layer.session.state, isA<SessionUnauthenticated>());
    expect(layer.session.currentUser, isNull);
  });

  test(
    'eight wrong codes are rate limited and cancel drops the challenge',
    () async {
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
      );
      addTearDown(layer.dispose);
      await layer.session.login(username: 'mfa.admin', password: 'demo-only');
      for (var i = 0; i < 7; i++) {
        await expectLater(
          layer.session.verifyMfa('111111'),
          throwsA(isA<MfaInvalidException>()),
        );
      }
      await expectLater(
        layer.session.verifyMfa('111111'),
        throwsA(isA<RateLimitedException>()),
      );
      expect(layer.session.state, isA<SessionOtpRequired>());
      await layer.session.cancelMfa();
      expect(layer.session.state, isA<SessionUnauthenticated>());
      await expectLater(
        layer.session.verifyMfa(FakeFixtures.mfaFixtureCode),
        throwsA(isA<MfaInvalidException>()),
      );
    },
  );

  test('mustChangePassword is honored only after the code succeeds', () async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(layer.dispose);
    await layer.session.login(
      username: 'mfa.mustchange',
      password: 'demo-only',
    );
    expect(layer.session.currentUser, isNull);
    await layer.session.verifyMfa(FakeFixtures.mfaFixtureCode);
    expect(layer.session.currentUser!.mustChangePassword, isTrue);
  });

  test('restart keeps a challenge cookie from becoming a session', () async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(layer.dispose);
    await layer.session.login(username: 'mfa.admin', password: 'demo-only');
    expect(layer.session.state, isA<SessionOtpRequired>());
    await layer.session.restore();
    expect(layer.session.state, isA<SessionUnauthenticated>());
    expect(layer.session.currentUser, isNull);
    expect(layer.permissions.role, AccountRole.unknown);
  });

  test(
    'a verify that finishes after cancel does not resurrect a session',
    () async {
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
        fakeLatency: const Duration(milliseconds: 250),
      );
      addTearDown(layer.dispose);
      await layer.session.login(username: 'mfa.admin', password: 'demo-only');
      final pending = layer.session.verifyMfa(FakeFixtures.mfaFixtureCode);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await layer.session.cancelMfa();
      await pending;
      expect(layer.session.state, isA<SessionUnauthenticated>());
      expect(layer.session.currentUser, isNull);
      await layer.session.restore();
      expect(layer.session.state, isA<SessionUnauthenticated>());
      expect(layer.session.currentUser, isNull);
    },
  );

  testWidgets('the code screen blocks the app until the code or cancel', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await signIn(tester, username: 'mfa.admin', password: 'demo-only');
    expect(find.byKey(MfaScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    expect(find.byKey(const Key('mfa-not-signed-in')), findsOneWidget);
    GoRouter.of(tester.element(find.byKey(MfaScreen.screenKey)))
        .go('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(MfaScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);

    await tester.enterText(find.byKey(MfaScreen.codeKey), '111111');
    await tester.tap(find.byKey(MfaScreen.submitKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MfaScreen.screenKey), findsOneWidget);
    expect(find.byKey(MfaScreen.errorKey), findsOneWidget);
    expect(find.text(FakeFixtures.mfaFixtureCode), findsNothing);

    await tester.enterText(
      find.byKey(MfaScreen.codeKey),
      FakeFixtures.mfaFixtureCode,
    );
    await tester.tap(find.byKey(MfaScreen.submitKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(MfaScreen.screenKey), findsNothing);
  });

  testWidgets('cancel returns to login without opening the home screen', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 800));
    await signIn(tester, username: 'mfa.admin', password: 'demo-only');
    await tester.tap(find.byKey(MfaScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
  });
}
