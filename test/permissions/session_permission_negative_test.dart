@Tags(['permissions-negative'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a 401 from a section read redirects to login and clears auth', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);
    expect(layer.permissions.fullAccess, isTrue);

    (layer.client as FakeApiClient).expireSession();
    await tester.tap(find.byKey(HomeShell.sectionKey(SectionKey.customers)));
    await settle(tester);

    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    expect(find.text(AppStrings.sessionExpired), findsOneWidget);
    expect(find.byKey(HomeShell.shellKey), findsNothing);
    final session = layer.session.state;
    expect(session, isA<SessionUnauthenticated>());
    expect((session as SessionUnauthenticated).reason, 'session_expired');
    expect(layer.permissions.fullAccess, isFalse);
    expect(layer.permissions.canRead(SectionKey.customers), isFalse);
  });

  testWidgets('logout clears user scope and back stays on the login screen', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(HomeShell.shellKey)),
    );
    container
            .read(accountQueryProvider(AccountSection.customers).notifier)
            .state =
        'secret-admin';

    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);

    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    expect(find.text(AppStrings.sessionExpired), findsNothing);
    expect(find.byKey(HomeShell.shellKey), findsNothing);
    expect(
      (layer.session.state as SessionUnauthenticated).reason,
      'logout',
    );
    expect(container.read(accountQueryProvider(AccountSection.customers)), '');
    expect(layer.permissions.canRead(SectionKey.customers), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await settle(tester);

    expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
    expect(find.byKey(HomeShell.shellKey), findsNothing);
    expect(find.text('secret-admin'), findsNothing);
  });

  testWidgets('the next user does not see the previous account', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.text('مدير تجريبي'), findsWidgets);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(HomeShell.shellKey)),
    );
    container
            .read(accountQueryProvider(AccountSection.customers).notifier)
            .state =
        'secret-admin';

    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    await signIn(tester, username: 'guest.demo', password: 'demo-only');

    expect(find.text('دور غير معروف'), findsOneWidget);
    expect(find.text('مدير تجريبي'), findsNothing);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.treasury)),
      findsNothing,
    );
    expect(find.textContaining('10,635'), findsNothing);
    expect(container.read(accountQueryProvider(AccountSection.customers)), '');
    expect(layer.permissions.fullAccess, isFalse);
    expect((layer.session.state as SessionAuthenticated).profile.id, 'u_9');
  });

  testWidgets(
    'a write in flight is not saved or resent, and a retry reuses its request id',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      final before = (await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      ))!;

      final gate = Completer<void>();
      fake.pauseMutations = gate;
      await tester.tap(find.byKey(const Key('add-payment')));
      await settle(tester);
      await enterAmount(tester, '100');
      await tester.tap(find.byKey(const Key('save-movement')));
      await tester.pump();
      await tester.pump(Duration.zero);
      expect(fake.mutationRequestIds, hasLength(1));
      final requestId = fake.mutationRequestIds.single;

      fake.expireSession();
      gate.complete();
      fake.pauseMutations = null;
      await settle(tester);

      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
      expect(find.text(AppStrings.sessionExpired), findsOneWidget);
      expect(fake.mutationRequestIds, [requestId]);

      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      final after = (await tester.runAsync(
        () => layer.accounts.get(AccountSection.customers, 'c_55'),
      ))!;
      expect(after.balanceUnits, before.balanceUnits);
      expect(after.version, before.version);
      await go(tester, '/customers/c_55');
      await tester.tap(find.byKey(const Key('add-payment')));
      await settle(tester);
      await enterAmount(tester, '100');
      await tester.pump();
      expect(fake.mutationRequestIds, [requestId]);

      await tester.tap(find.byKey(const Key('save-movement')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(fake.mutationRequestIds, [requestId, requestId]);
    },
  );
}

Future<void> enterAmount(WidgetTester tester, String value) async {
  await tester.enterText(
    find
        .descendant(
          of: find.byKey(const Key('movement-amount')),
          matching: find.byType(TextField),
        )
        .hitTestable(),
    value,
  );
  await tester.pump();
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
