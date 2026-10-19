import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';
import 'package:vib_abdo_company_mobile/ui/presentation.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  test('unread badge uses the server count and caps at 99', () {
    expect(badgeLabel(null), isNull);
    expect(badgeLabel(0), isNull);
    expect(badgeLabel(1), '1');
    expect(badgeLabel(98), '98');
    expect(badgeLabel(99), '99');
    expect(badgeLabel(140), '99');
  });

  testWidgets('login is RTL and does not offer an external account', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    expectRtl(tester);
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    expect(find.text(AppStrings.slogan), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.byKey(const Key('signup-link')), findsOneWidget);
  });

  testWidgets('home keeps shortcuts when the summary request fails', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      overrides: [
        homeDashboardProvider.overrideWithValue(
          AsyncError<HomeDto?>(const NetworkException(), StackTrace.empty),
        ),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');

    expect(find.text(AppStrings.homeError), findsOneWidget);
    expect(find.byKey(HomeDashboard.retryKey), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.collections)),
      findsOneWidget,
    );
    expect(find.byKey(HomeShell.sectionKey(SectionKey.treasury)), findsNothing);
  });

  testWidgets(
    'a phone keeps five tabs and opens the menu from the start edge',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(360, 800));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');

      expectRtl(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(5));
      expect(find.text(AppStrings.more), findsOneWidget);
      expect(find.text(AppStrings.settings), findsNothing);

      await tester.tap(find.byKey(HomeShell.menuKey));
      await settle(tester);
      final drawer = tester.getRect(find.byType(Drawer));
      expect(drawer.right, moreOrLessEquals(360, epsilon: 1));
      expect(find.text(AppStrings.settings), findsOneWidget);
    },
  );

  testWidgets('a wide window uses the side list instead of a bottom bar', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1100, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text(AppStrings.organization), findsOneWidget);
    expect(find.text('مدير تجريبي'), findsOneWidget);
  });

  testWidgets('allowed screens render RTL in dark mode', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await settle(tester);

    final screens = <String, Key>{
      '/': HomeDashboard.screenKey,
      '/customers': const Key('screen-customers'),
      '/companies': const Key('screen-companies'),
      '/customers/c_55': const Key('screen-ledger-customers'),
      '/companies/c_55': const Key('screen-ledger-companies'),
      '/libyan-deposits': const Key('screen-libyan-deposits'),
      '/egyptian-deposits': const Key('screen-egyptian-deposits'),
      '/purchases': const Key('screen-purchases'),
      '/collections': const Key('screen-collections'),
      '/treasury': const Key('screen-treasury'),
      '/reports': const Key('screen-reports'),
      '/settings': const Key('screen-settings'),
      '/account': const Key('screen-account'),
      '/notifications': const Key('screen-notifications'),
    };

    for (final entry in screens.entries) {
      await go(tester, entry.key);
      expectRtl(tester);
      expect(
        Theme.of(tester.element(find.byType(HomeShell))).brightness,
        Brightness.dark,
      );
      expect(find.byKey(entry.value), findsOneWidget);
    }

    await go(tester, '/customers');
    expect(find.byKey(const Key('add-account')), findsOneWidget);
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    expect(find.byKey(const Key('add-payment')), findsOneWidget);
    await go(tester, '/companies/c_55');
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    await go(tester, '/purchases');
    expect(find.byKey(const Key('add-purchase')), findsOneWidget);
    expect(find.byKey(const Key('finalize-day')), findsOneWidget);
    await go(tester, '/treasury');
    expect(find.byKey(const Key('cash-in')), findsOneWidget);
    expect(find.byKey(const Key('cash-out')), findsOneWidget);
    await go(tester, '/collections');
    expect(find.byKey(const Key('approve-sb_1')), findsOneWidget);
    expect(find.byKey(const Key('cash-sb_2')), findsOneWidget);
    expect(find.byKey(const Key('close-batch')), findsOneWidget);
    await go(tester, '/egyptian-deposits');
    expect(find.byKey(const Key('save-rate')), findsOneWidget);
    await go(tester, '/settings');
    expect(find.textContaining('نسخ'), findsNothing);
    expect(find.byKey(const Key('financial-ledger')), findsOneWidget);
  });

  testWidgets('a reader without write permission does not see write controls', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');

    await go(tester, '/customers');
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    expect(find.byKey(const Key('add-account')), findsNothing);
    expect(find.byKey(const Key('assign-mode')), findsNothing);

    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsNothing);
    expect(find.byKey(const Key('add-payment')), findsNothing);
    expect(find.byKey(const Key('cancel-tx_1')), findsNothing);

    await go(tester, '/collections');
    expect(find.byKey(const Key('screen-collections')), findsOneWidget);
    expect(find.byKey(const Key('submit-as_1')), findsOneWidget);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    expect(find.byKey(const Key('cash-sb_2')), findsNothing);
    expect(find.byKey(const Key('close-batch')), findsNothing);

    for (final path in [
      '/companies',
      '/companies/c_55',
      '/libyan-deposits',
      '/egyptian-deposits',
      '/purchases',
      '/treasury',
      '/reports',
      '/settings',
    ]) {
      await go(tester, path);
      expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
      expect(find.byKey(ForbiddenPane.paneKey), findsNothing);
    }

    expect(find.byKey(const Key('cash-in')), findsNothing);
    expect(find.byKey(const Key('add-purchase')), findsNothing);
    expect(find.byKey(const Key('finalize-day')), findsNothing);
    expect(find.byKey(const Key('save-rate')), findsNothing);

    await go(tester, '/account');
    expect(find.byKey(const Key('screen-account')), findsOneWidget);
    expectRtl(tester);
    await go(tester, '/notifications');
    expect(find.byKey(const Key('screen-notifications')), findsOneWidget);
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('an unknown role sees no section controls', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'guest.demo', password: 'demo-only');
    await go(tester, '/treasury');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsNothing);
    expect(find.byKey(const Key('cash-in')), findsNothing);
    await go(tester, '/collections');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsNothing);
    expect(find.byKey(const Key('submit-as_1')), findsNothing);
  });
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
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
