import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import '../support/pump_app.dart';

/// Phase 5 UI checks on the Fake API. Server status codes are in
/// `phase5_server_test.dart`.
void main() {
  testWidgets('P5-10 full admin sees the totals board and admin routes', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    expect(find.text(AppStrings.employeeTotals), findsOneWidget);
    expect(find.text('موظف استلام تجريبي'), findsWidgets);
    expect(find.text(AppStrings.payroll), findsOneWidget);
    expect(find.byKey(const Key('payroll-u_12')), findsOneWidget);
    expect(find.byKey(const Key('payroll-u_1')), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsOneWidget);
    expect(find.byKey(const Key('reject-sb_1')), findsOneWidget);

    await go(tester, '/settings');
    expect(find.byKey(const Key('financial-ledger')), findsOneWidget);
    await go(tester, '/settings/employees');
    expect(find.byKey(const Key('screen-settings-employees')), findsOneWidget);
    await go(tester, '/reports');
    expect(find.byKey(const Key('screen-reports')), findsOneWidget);
    expect(find.text(AppStrings.save), findsNothing);
  });

  testWidgets('P5-20 limited admin sees the board and not settings', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 2400));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.text(AppStrings.employeeTotals), findsOneWidget);
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    expect(find.text(AppStrings.myPayroll), findsOneWidget);
    expect(find.text(AppStrings.payroll), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsOneWidget);
    expect(find.byKey(const Key('reject-sb_1')), findsOneWidget);
    expect(find.byKey(const Key('cash-sb_2')), findsNothing);
    expect(find.byKey(const Key('close-batch')), findsNothing);

    for (final path in _adminPaths) {
      await go(tester, path);
      expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
      expect(find.byKey(const Key('screen-settings-employees')), findsNothing);
      expect(find.byKey(const Key('financial-ledger')), findsNothing);
    }
  });

  testWidgets('P5-30 employee sees only permitted collections data', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 2400));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');

    expect(find.byKey(HomeShell.sectionKey(SectionKey.customers)), findsOneWidget);
    expect(find.byKey(HomeShell.sectionKey(SectionKey.collections)), findsOneWidget);
    expect(find.byKey(HomeShell.sectionKey(SectionKey.treasury)), findsNothing);
    expect(find.byKey(HomeShell.sectionKey(SectionKey.reports)), findsNothing);
    expect(find.byKey(HomeShell.sectionKey(SectionKey.companies)), findsNothing);

    await go(tester, '/collections');
    expect(find.text(AppStrings.employeeTotals), findsNothing);
    expect(find.byKey(const Key('collections-metrics')), findsNothing);
    expect(find.text(AppStrings.myPayroll), findsOneWidget);
    expect(find.byKey(const Key('payroll-u_12')), findsOneWidget);
    expect(find.byKey(const Key('payroll-u_1')), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    expect(find.byKey(const Key('reject-sb_1')), findsNothing);
    expect(find.byKey(const Key('submit-as_1')), findsOneWidget);

    await go(tester, '/customers/c_56');
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);

    for (final path in _adminPaths) {
      await go(tester, path);
      expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
      expect(find.text(AppStrings.employeeTotals), findsNothing);
    }
  });

  testWidgets('P5-40 guest and flag.admin have no admin or section screens', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'guest.demo', password: 'demo-only');
    expect(find.text(AppStrings.roleUnknown), findsOneWidget);
    expect(find.text(AppStrings.noSections), findsOneWidget);
    for (final path in ['/collections', '/customers/c_55', ..._adminPaths]) {
      await go(tester, path);
      expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
      expect(find.text(AppStrings.employeeTotals), findsNothing);
    }

    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    await signIn(tester, username: 'flag.admin.demo', password: 'demo-only');
    expect(find.text(AppStrings.noSections), findsOneWidget);
    expect(find.text(AppStrings.roleUnknown), findsNothing);
    for (final path in ['/collections', ..._adminPaths]) {
      await go(tester, path);
      expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
      expect(find.byKey(const Key('financial-ledger')), findsNothing);
    }
  });

  testWidgets('P5-13 logout blocks screens and the Android back path', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    expect(find.text(AppStrings.employeeTotals), findsOneWidget);
    await go(tester, '/settings/employees');
    expect(find.byKey(const Key('screen-settings-employees')), findsOneWidget);

    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    _expectSignedOut(tester, expired: false);

    await _goFromLogin(tester, '/collections');
    _expectSignedOut(tester, expired: false);
    await _goFromLogin(tester, '/settings/employees');
    _expectSignedOut(tester, expired: false);

    await tester.binding.handlePopRoute();
    await settle(tester);
    _expectSignedOut(tester, expired: false);
  });

  testWidgets('P5-60 an expired session shows the notice and blocks routes', (
    tester,
  ) async {
    final api = await pumpFakeApp(tester, size: const Size(390, 1600));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    expect(find.byKey(const Key('submit-as_1')), findsOneWidget);

    await api.session.forceLogout('session_expired');
    await settle(tester);
    _expectSignedOut(tester, expired: true);

    await _goFromLogin(tester, '/collections');
    _expectSignedOut(tester, expired: true);
    await tester.binding.handlePopRoute();
    await settle(tester);
    _expectSignedOut(tester, expired: true);
  });

  testWidgets('P5-63 resume keeps the current permissions', (tester) async {
    final api = await pumpFakeApp(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(api.permissions.fullAccess, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(api.session.state, isA<SessionAuthenticated>());
    expect(api.permissions.fullAccess, isTrue);
    expect(api.permissions.role, AccountRole.admin);
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
  });
}

const _adminPaths = [
  '/settings',
  '/settings/employees',
  '/settings/audit',
  '/settings/operations',
  '/treasury',
  '/reports',
  '/companies',
  '/masraweya',
  '/purchases',
];

void _expectSignedOut(WidgetTester tester, {required bool expired}) {
  expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  expect(find.byKey(HomeShell.shellKey), findsNothing);
  expect(find.text(AppStrings.employeeTotals), findsNothing);
  expect(find.byKey(const Key('screen-settings-employees')), findsNothing);
  expect(find.byKey(const Key('submit-as_1')), findsNothing);
  expect(find.text('موظف استلام تجريبي'), findsNothing);
  if (expired) {
    expect(find.text(AppStrings.sessionExpired), findsOneWidget);
  } else {
    expect(find.text(AppStrings.sessionExpired), findsNothing);
  }
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> _goFromLogin(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(LoginScreen.screenKey));
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
