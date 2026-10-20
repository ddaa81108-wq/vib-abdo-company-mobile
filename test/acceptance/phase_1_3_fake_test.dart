import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import '../support/pump_app.dart';

/// Acceptance evidence for phases 1–3 on the Fake API.
///
/// These tests only observe the current client. They do not change production
/// code and they do not assert the known fake-server gaps (stale balances,
/// limited-admin 403, missing optimistic lock).
void main() {
  test('employee management calls are forbidden by the fake server', () async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    addTearDown(api.dispose);
    await api.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );

    const message = 'هذا الإجراء للإدارة فقط';
    await expectLater(
      api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: MutationMeta(expectedVersion: 1),
      ),
      throwsA(
        isA<ForbiddenException>().having((e) => e.message, 'message', message),
      ),
    );
    await expectLater(
      api.collections.markCashReceived(
        'sb_2',
        MutationMeta(expectedVersion: 3),
      ),
      throwsA(
        isA<ForbiddenException>().having((e) => e.message, 'message', message),
      ),
    );
    await expectLater(
      api.collections.closeDay(batchId: 'b_1', meta: MutationMeta()),
      throwsA(
        isA<ForbiddenException>().having((e) => e.message, 'message', message),
      ),
    );
    await expectLater(
      api.collections.assign(
        customerIds: const ['c_55'],
        assigneeUserId: 'u_12',
        section: 'customers',
        meta: MutationMeta(),
      ),
      throwsA(
        isA<ForbiddenException>().having((e) => e.message, 'message', message),
      ),
    );

    await api.session.logout();
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(api.permissions.role, AccountRole.unknown);
  });

  testWidgets('limited admin and unknown role deep links return home', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');

    for (final path in ['/treasury', '/reports', '/settings', '/companies']) {
      await go(tester, path);
      expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    }
    expect(find.byKey(HomeShell.sectionKey(SectionKey.treasury)), findsNothing);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.customers)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    await signIn(tester, username: 'guest.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.text(AppStrings.roleUnknown), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsNothing);
  });

  testWidgets('full access false cannot open settings by direct link', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'flag.admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(const Key('financial-ledger')), findsNothing);
    expect(find.text(AppStrings.noSections), findsOneWidget);
  });

  testWidgets('full payment is hidden on both deposit ledgers', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('full-payment')), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsOneWidget);

    await go(tester, '/libyan-deposits/c_55');
    expect(find.byKey(const Key('full-payment')), findsNothing);
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    expect(find.text(AppStrings.depositIn), findsWidgets);
    expect(find.text(AppStrings.fullPayment), findsNothing);

    await go(tester, '/egyptian-deposits/c_55');
    expect(find.byKey(const Key('full-payment')), findsNothing);
    expect(find.text(AppStrings.egpIn), findsWidgets);
    expect(find.text(AppStrings.fullPayment), findsNothing);
    // The fake client schedules a zero-length delay per request. Drain it so
    // the test binding does not see a pending timer after the last navigation.
    await tester.pump(const Duration(seconds: 1));
  });
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
