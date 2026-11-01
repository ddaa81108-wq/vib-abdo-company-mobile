import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notifications_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/employee_totals_screen.dart';
import 'package:vib_abdo_company_mobile/features/splash/splash_screen.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/section_labels.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/soft_tile.dart';

import 'support/pump_app.dart';

void main() {
  test('home columns collapse when text is large', () {
    expect(homeCardColumns(320, 1), 1);
    expect(homeCardColumns(360, 1), 1);
    expect(homeCardColumns(393, 1), 2);
    expect(homeCardColumns(430, 1), 2);
    expect(homeCardColumns(430, 1.3), 1);
    expect(homeCardColumns(430, 2), 1);
  });

  test('DEF-010 view all opens the section it belongs to when readable', () {
    for (final section in SectionKey.values) {
      final allowed = PermissionService()
        ..applyFromServer(
          [section.read.code],
          role: 'employee',
          sectionAccess: {
            if (section.accessKey != null) section.accessKey!: 'read',
          },
        );
      expect(
        homeShowAllPath(section.key, allowed),
        '/${section.key}',
        reason: section.key,
      );

      final noCode = PermissionService()
        ..applyFromServer(
          const <String>[],
          role: 'employee',
          sectionAccess: const {},
        );
      expect(homeShowAllPath(section.key, noCode), isNull, reason: section.key);

      if (section.accessKey != null) {
        final blocked = PermissionService()
          ..applyFromServer(
            [section.read.code],
            role: 'employee',
            sectionAccess: {section.accessKey!: 'none'},
          );
        expect(
          homeShowAllPath(section.key, blocked),
          isNull,
          reason: section.key,
        );
      }
    }

    final both = PermissionService()
      ..applyFromServer(
        const ['debts.read', 'companies.read'],
        role: 'employee',
        sectionAccess: const {'customerDebts': 'read', 'companyDebts': 'read'},
      );
    expect(homeShowAllSections(const ['companies', 'customers'], both), [
      'companies',
      'customers',
    ]);
    expect(homeShowAllPath('companies', both), '/companies');
    expect(homeShowAllPath('customers', both), '/customers');
  });

  for (final dark in [false, true]) {
    testWidgets(
      'login, home, settings, account, and notifications hold at phone sizes (${dark ? 'dark' : 'light'})',
      (tester) async {
        for (final width in [320.0, 360.0, 393.0, 430.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            await _openGroup(
              tester,
              width: width,
              scale: scale,
              dark: dark,
              height: scale >= 1.3 ? 1200 : 900,
            );
          }
        }
      },
    );
  }

  testWidgets('the rail and the side list keep their labels', (tester) async {
    for (final width in [720.0, 1100.0]) {
      for (final scale in [1.0, 2.0]) {
        await pumpFakeApp(
          tester,
          size: Size(width, scale >= 2 ? 1400 : 1000),
          textScale: scale,
        );
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        expectRtl(tester);
        expect(find.byType(PhoneBottomNav), findsNothing);
        if (width > 900) {
          expect(find.byKey(HomeShell.panelKey), findsOneWidget);
          expect(find.byKey(HomeShell.railKey), findsNothing);
          expect(find.text(AppStrings.organization), findsOneWidget);
        } else {
          expect(find.byKey(HomeShell.railKey), findsOneWidget);
          expect(find.byKey(HomeShell.panelKey), findsNothing);
          expect(find.text(AppStrings.organization), findsNothing);
        }
        expect(find.text('مدير تجريبي'), findsOneWidget);
        expect(find.text(AppStrings.settings), findsWidgets);
        final nav = width > 900 ? HomeShell.panelKey : HomeShell.railKey;
        await tester.scrollUntilVisible(
          find.text(AppStrings.myAccount),
          160,
          scrollable: find.descendant(
            of: find.byKey(nav),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text(AppStrings.myAccount), findsWidgets);
        await go(tester, '/settings');
        expect(find.byKey(const Key('screen-settings')), findsOneWidget);
        await go(tester, '/notifications');
        expect(find.byKey(NotificationsScreen.screenKey), findsOneWidget);
      }
    }
  });

  testWidgets('admin bottom bar stays on one row at 320 and 360', (
    tester,
  ) async {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 2.0]) {
        await pumpFakeApp(
          tester,
          size: Size(width, scale >= 2 ? 1200 : 900),
          textScale: scale,
        );
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        final bar = tester.widget<PhoneBottomNav>(find.byType(PhoneBottomNav));
        expect(bar.tabs, hasLength(5));
        final tops = [
          for (final tab in bar.tabs)
            tester.getRect(find.byKey(Key('bottom-tab-${tab.id}'))).top,
        ];
        expect(
          tops.toSet(),
          hasLength(1),
          reason: 'width $width scale $scale tops $tops',
        );
      }
    }
  });

  testWidgets('disclosure chevrons mirror in RTL', (tester) async {
    await pumpFakeApp(tester, size: const Size(360, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expectRtl(tester);
    // Home section tiles (icon grid) carry no disclosure chevron.
    expect(
      find.descendant(
        of: find.byKey(HomeShell.sectionKey(SectionKey.customers)),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsNothing,
    );

    await go(tester, '/settings');
    expectChevronMirrors(
      tester,
      find.byKey(const Key('settings-link-employees')),
    );
    expectChevronMirrors(tester, find.byKey(const Key('settings-link-audit')));
    expectChevronMirrors(
      tester,
      find.byKey(const Key('settings-link-operations')),
    );

    await go(tester, '/');
    await tester.ensureVisible(find.byKey(const Key('bottom-tab-more')));
    await tester.tap(find.byKey(const Key('bottom-tab-more')));
    await settle(tester);
    expectChevronMirrors(tester, find.byKey(const Key('more-settings')));
    expectChevronMirrors(tester, find.byKey(const Key('more-account')));
  });

  testWidgets('a failed startup offers retry on the splash', (tester) async {
    for (final dark in [false, true]) {
      var attempts = 0;
      await pumpFakeApp(
        tester,
        size: const Size(360, 900),
        overrides: [
          if (dark) themeModeProvider.overrideWith(_DarkTheme.new),
          startupProvider.overrideWith((ref) async {
            attempts++;
            if (attempts < 2) throw StateError('restore failed');
            final session = ref.read(apiLayerProvider).session;
            if (session.state is SessionUnknown) {
              await session.restore();
            }
          }),
        ],
      );
      expect(find.byKey(SplashScreen.screenKey), findsOneWidget);
      expect(find.byKey(SplashScreen.retryKey), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(find.text(AppStrings.loading), findsNothing);
      expectRtl(tester);
      final context = tester.element(find.byKey(SplashScreen.retryKey));
      final theme = Theme.of(context);
      expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
        theme.colorScheme.error,
      );
      await tester.tap(find.byKey(SplashScreen.retryKey));
      await settle(tester);
      expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
      expect(find.byKey(SplashScreen.retryKey), findsNothing);
    }
  });

  testWidgets('a phone drawer and more sheet list only permitted rows', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byType(PhoneBottomNav), findsOneWidget);
    // Home shows the settings tile; the drawer lists its own settings row.
    expect(find.byKey(HomeDashboard.settingsTileKey), findsOneWidget);

    await tester.tap(find.byKey(HomeShell.menuKey));
    await settle(tester);
    final drawer = tester.getRect(find.byType(Drawer));
    expect(drawer.right, moreOrLessEquals(360, epsilon: 1));
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text(AppStrings.settings),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.employeesTile), findsNothing);
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await settle(tester);

    await tester.ensureVisible(find.byKey(const Key('bottom-tab-more')));
    await tester.tap(find.byKey(const Key('bottom-tab-more')));
    await settle(tester);
    expect(find.byKey(const Key('more-sheet')), findsOneWidget);
    expect(find.byKey(const Key('more-settings')), findsOneWidget);
    expect(find.byKey(const Key('more-account')), findsOneWidget);
    expect(find.text(AppStrings.employeesTile), findsNothing);
  });

  testWidgets('an employee does not see settings or admin routes', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.collections)),
      findsOneWidget,
    );
    // The tiles show names only; write access stays in the home summary.
    expect(homeWritable(tester), contains(SectionKey.collections));
    expect(homeWritable(tester), isNot(contains(SectionKey.customers)));
    expect(
      find.byKey(HomeShell.writeKey(SectionKey.collections)),
      findsNothing,
    );
    expect(find.byKey(HomeShell.sectionKey(SectionKey.treasury)), findsNothing);
    expect(find.text(AppStrings.settings), findsNothing);

    await tester.tap(find.byKey(HomeShell.menuKey));
    await settle(tester);
    expect(find.text(AppStrings.settings), findsNothing);
    expect(find.text(AppStrings.myAccount), findsWidgets);
    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await settle(tester);

    await go(tester, '/settings');
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    await go(tester, '/settings/employees');
    expect(find.byKey(const Key('screen-settings-employees')), findsNothing);
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    await go(tester, '/account');
    expect(find.byKey(const Key('screen-account')), findsOneWidget);
    expectRtl(tester);
    await go(tester, '/notifications');
    expect(find.byKey(NotificationsScreen.screenKey), findsOneWidget);
  });

  testWidgets('guest and flag admin see no sections and no settings', (
    tester,
  ) async {
    for (final username in ['guest.demo', 'flag.admin.demo']) {
      await pumpFakeApp(tester, size: const Size(393, 900));
      await signIn(tester, username: username, password: 'demo-only');
      expect(find.text(AppStrings.noSections), findsOneWidget);
      expect(find.text(AppStrings.settings), findsNothing);
      for (final section in SectionKey.values) {
        expect(find.byKey(HomeShell.sectionKey(section)), findsNothing);
        expect(find.byKey(HomeShell.writeKey(section)), findsNothing);
      }
      await go(tester, '/settings/audit');
      expect(find.byKey(const Key('screen-settings-audit')), findsNothing);
      expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
      expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    }
  });

  testWidgets('limited admin has no settings entry', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 900));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');
    expect(
      find.byKey(HomeShell.actionKey(ManagementAction.settingsManage)),
      findsNothing,
    );
    expect(find.text(AppStrings.settings), findsNothing);
    await go(tester, '/settings/operations');
    expect(find.byKey(const Key('screen-settings-operations')), findsNothing);
  });

  testWidgets('settings.manage opens empty admin screens and not the ledger', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 1000));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    layer.permissions.applyFromServer(
      const ['settings.manage'],
      role: 'admin',
      sectionAccess: const {},
    );
    await tester.pump();
    await go(tester, '/settings');
    expect(find.byKey(const Key('screen-settings')), findsOneWidget);
    expect(find.byKey(const Key('financial-ledger')), findsNothing);
    expect(find.text(AppStrings.employeesTile), findsOneWidget);
    expect(find.text(AppStrings.unavailable), findsNothing);

    await tester.tap(find.byKey(const Key('settings-link-employees')));
    await settle(tester);
    expect(find.byKey(EmployeeTotalsScreen.screenKey), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text(AppStrings.employeesEmpty), findsNothing);
    expect(find.text('موظف استلام تجريبي'), findsNothing);

    await go(tester, '/settings/audit');
    expect(find.byKey(const Key('screen-settings-audit')), findsOneWidget);
    expect(find.text(AppStrings.auditEmpty), findsOneWidget);

    await go(tester, '/settings/operations');
    expect(find.byKey(const Key('screen-settings-operations')), findsOneWidget);
    expect(find.text(AppStrings.operationsEmpty), findsOneWidget);
  });

  testWidgets('phone status strip: role on the right, status on the left', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    // The old centred identity block is gone from the page body.
    expect(find.text(AppStrings.signedInAs), findsNothing);
    final strip = find.byType(ConnectionBanner);
    expect(strip, findsOneWidget);
    final role = find.descendant(
      of: strip,
      matching: find.byKey(HomeShell.roleKey),
    );
    expect(role, findsOneWidget);
    expect(tester.widget<Text>(role).data, AppStrings.roleAdmin);
    final status = find.byKey(const Key('online-banner'));
    expect(tester.widget<Text>(status).data, 'متصل • محفوظ');
    // RTL: the role hugs the right edge, the status sits to its left.
    expect(tester.getRect(role).right, greaterThan(340));
    expect(tester.getRect(status).right, lessThan(tester.getRect(role).left));
    expect(tester.getRect(status).center.dx, lessThan(180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window keeps the role in the side list only', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1100, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.roleKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ConnectionBanner),
        matching: find.byKey(HomeShell.roleKey),
      ),
      findsNothing,
    );
  });

  testWidgets('home is the icon grid only, ending with the settings tile', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final grid = find.byKey(const Key('home-tile-grid'));
    expect(grid, findsOneWidget);
    for (final section in SectionKey.values) {
      expect(
        find.descendant(
          of: grid,
          matching: find.byKey(HomeShell.sectionKey(section)),
        ),
        findsOneWidget,
      );
    }
    expect(find.byKey(HomeDashboard.settingsTileKey), findsOneWidget);
    // The settings tile is last, after the nine sections.
    final tiles = tester.widget<Wrap>(grid).children;
    expect(tiles, hasLength(SectionKey.values.length + 1));
    // Removed from home (Ali, 2026-11-01): summary, bulletin, actions, date.
    expect(find.text(AppStrings.homeCardsTitle), findsNothing);
    expect(find.text(AppStrings.oldDebtsTitle), findsNothing);
    expect(find.text(AppStrings.actionsTitle), findsNothing);
    expect(find.byKey(const Key('home-business-date')), findsNothing);
    expect(find.byKey(const Key('home-fallback-banner')), findsNothing);
    expect(find.byKey(const Key('old-debt-c_55')), findsNothing);
    expect(find.byKey(const Key('show-all-customers')), findsNothing);
    for (final action in ManagementAction.values) {
      expect(find.byKey(HomeShell.actionKey(action)), findsNothing);
    }

    await tester.ensureVisible(find.byKey(HomeDashboard.settingsTileKey));
    await tester.tap(find.byKey(HomeDashboard.settingsTileKey));
    await settle(tester);
    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
      '/settings',
    );
  });

  testWidgets('DEF-012 admin settings replace the old unavailable sentence', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 1100));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    const routes = <String, (Key, String, String)>{
      '/settings/employees': (
        Key('screen-settings-employees'),
        AppStrings.employeesTile,
        AppStrings.employeesEmpty,
      ),
      '/settings/audit': (
        Key('screen-settings-audit'),
        AppStrings.auditTile,
        AppStrings.auditEmpty,
      ),
      '/settings/operations': (
        Key('screen-settings-operations'),
        AppStrings.operationsTile,
        AppStrings.operationsEmpty,
      ),
    };
    for (final entry in routes.entries) {
      await go(tester, entry.key);
      expect(find.byKey(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsWidgets);
      expect(find.text(entry.value.$3), findsOneWidget);
      expect(find.text(AppStrings.unavailable), findsNothing);
      expect(find.textContaining('لا تتوفر بيانات من الخادم'), findsNothing);
    }
  });

  testWidgets('offline disables notification writes and account edits', (
    tester,
  ) async {
    final link = ToggleConnectivity(true);
    await pumpFakeApp(tester, size: const Size(360, 1000), connectivity: link);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('mark-all-read')))
          .onPressed,
      isNotNull,
    );
    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('mark-all-read')))
          .onPressed,
      isNull,
    );

    await go(tester, '/account');
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('sound-switch')))
          .onChanged,
      isNull,
    );
    final password = tester.widget<SoftTile>(
      find.byKey(const Key('account-password')),
    );
    expect(password.onTap, isNull);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('theme-switch')))
          .onChanged,
      isNotNull,
    );
  });

  testWidgets('P4-003 settings empty states and Arabic ledger labels', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 1200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    expect(find.text(AppStrings.unavailable), findsNothing);
    expect(find.textContaining('لا تتوفر بيانات من الخادم'), findsNothing);
    expect(find.textContaining('LYD'), findsNothing);
    expect(find.textContaining('EGP'), findsNothing);
    expect(find.byKey(const Key('ledger-total-LYD')), findsOneWidget);
    expect(find.byKey(const Key('ledger-total-EGP')), findsOneWidget);
    expect(
      tester.widget<MoneyText>(find.byKey(const Key('ledger-total-LYD'))).text,
      '480 د.ل',
    );
    expect(
      tester.widget<MoneyText>(find.byKey(const Key('ledger-total-EGP'))).text,
      '10,000 ج.م',
    );

    await go(tester, '/settings/employees');
    expect(find.text(AppStrings.employeesEmpty), findsOneWidget);
    expect(find.textContaining('لا تتوفر بيانات من الخادم'), findsNothing);
    await go(tester, '/settings/audit');
    expect(find.text(AppStrings.auditEmpty), findsOneWidget);
    expect(find.textContaining('لا تتوفر بيانات من الخادم'), findsNothing);
    await go(tester, '/settings/operations');
    expect(find.text(AppStrings.operationsEmpty), findsOneWidget);
    expect(find.textContaining('لا تتوفر بيانات من الخادم'), findsNothing);
  });

  testWidgets('notifications show an error with retry and an empty state', (
    tester,
  ) async {
    final gate = _Gate();
    await pumpFakeApp(
      tester,
      size: const Size(360, 900),
      overrides: [
        notificationsProvider.overrideWithBuild((ref, _) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).notifications.list();
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/notifications');
    expect(find.byKey(NotificationsScreen.retryKey), findsOneWidget);
    gate.failing = false;
    await tester.tap(find.byKey(NotificationsScreen.retryKey));
    await settle(tester);
    expect(find.byKey(const Key('notice-77')), findsOneWidget);
    expect(find.byKey(NotificationsScreen.retryKey), findsNothing);
    expect(gate.calls, greaterThanOrEqualTo(2));
  });
}

Future<void> _openGroup(
  WidgetTester tester, {
  required double width,
  required double scale,
  required bool dark,
  required double height,
}) async {
  await pumpFakeApp(tester, size: Size(width, height), textScale: scale);
  if (dark) {
    await tester.tap(find.byKey(LoginScreen.themeKey));
    await settle(tester);
    expect(
      Theme.of(tester.element(find.byType(LoginScreen))).brightness,
      Brightness.dark,
    );
  }
  expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  expectRtl(tester);
  expect(find.text(AppStrings.slogan), findsOneWidget);
  expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
  expect(find.text(AppStrings.signIn), findsWidgets);

  await signIn(tester, username: 'admin.demo', password: 'demo-only');
  expect(find.byKey(HomeShell.shellKey), findsOneWidget);
  expectRtl(tester);
  expect(
    Theme.of(tester.element(find.byType(HomeShell))).brightness,
    dark ? Brightness.dark : Brightness.light,
  );
  expect(find.byType(PhoneBottomNav), findsOneWidget);
  final bar = tester.widget<PhoneBottomNav>(find.byType(PhoneBottomNav));
  expect(bar.tabs, hasLength(5));
  expect(find.byKey(const Key('home-fallback-banner')), findsNothing);

  const screens = <String, Key>{
    '/notifications': NotificationsScreen.screenKey,
    '/account': Key('screen-account'),
    '/settings': Key('screen-settings'),
    '/settings/employees': Key('screen-settings-employees'),
    '/settings/audit': Key('screen-settings-audit'),
    '/settings/operations': Key('screen-settings-operations'),
    '/': HomeDashboard.screenKey,
  };
  for (final entry in screens.entries) {
    await go(tester, entry.key);
    expectRtl(tester);
    expect(find.byKey(entry.value), findsOneWidget);
    expect(find.text(AppStrings.unavailable), findsNothing);
  }
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

void expectChevronMirrors(WidgetTester tester, Finder scope) {
  final icons = find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Icons.chevron_right,
    ),
  );
  expect(icons, findsOneWidget);
  final icon = tester.widget<Icon>(icons);
  expect(icon.textDirection, TextDirection.rtl);
  final transform = find.descendant(
    of: icons,
    matching: find.byType(Transform),
  );
  expect(transform, findsOneWidget);
  expect(tester.widget<Transform>(transform).transform.storage[0], lessThan(0));
}

class _DarkTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
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

class _Gate {
  var failing = true;
  var calls = 0;
}
