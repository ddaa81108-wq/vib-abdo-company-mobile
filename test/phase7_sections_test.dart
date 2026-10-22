import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notifications_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/employee_totals_screen.dart';
import 'package:vib_abdo_company_mobile/state/employee_totals_provider.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// P7-06 and P7-07. The login form builds the session. Nothing overrides
/// homeDashboardProvider or any other provider under test. Loading and
/// errors come from FakeApiClient gates.
void main() {
  testWidgets('P7-06 admin reads every section from the signed-in session', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    // 🔶 GET /api/home. The date and the customers net are server literals.
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(const Key('home-business-date')), findsOneWidget);
    expect(find.text('2026-10-19'), findsWidgets);
    expect(
      _inside(HomeShell.summaryKey('customers.netBalance'), '10,635 د.ل'),
      findsOneWidget,
    );

    await go(tester, '/customers');
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    expect(find.text('10,635 د.ل'), findsWidgets);
    expect(find.text('عميل تجريبي'), findsWidgets);

    await go(tester, '/collections');
    expect(find.byKey(const Key('screen-collections')), findsOneWidget);
    expect(find.byKey(const Key('assignment-as_1')), findsOneWidget);

    await go(tester, '/companies');
    expect(find.byKey(const Key('screen-companies')), findsOneWidget);
    expect(find.text('1,035 د.ل'), findsWidgets);
    expect(find.text('شركة تجريبية ١٠'), findsOneWidget);

    await go(tester, '/libyan-deposits');
    expect(find.byKey(const Key('screen-libyan-deposits')), findsOneWidget);
    expect(find.text('695 د.ل'), findsWidgets);
    expect(find.text('أمانة ليبية تجريبية ١٠'), findsOneWidget);

    await go(tester, '/egyptian-deposits');
    expect(find.byKey(const Key('screen-egyptian-deposits')), findsOneWidget);
    expect(find.text('23,750 ج.م'), findsWidgets);

    await go(tester, '/masraweya');
    expect(find.byKey(const Key('screen-masraweya')), findsOneWidget);
    final money = MoneyFormatter();
    expect(
      _inside(
        const Key('masraweya-work-total'),
        money.format(3050, Currency.egp),
      ),
      findsOneWidget,
    );
    expect(
      _inside(
        const Key('masraweya-remaining'),
        money.format(8950, Currency.egp),
      ),
      findsOneWidget,
    );

    await go(tester, '/purchases');
    expect(find.byKey(const Key('screen-purchases')), findsOneWidget);
    expect(
      _inside(const Key('purchases-lifetime'), '2,553 د.ل'),
      findsOneWidget,
    );
    expect(find.text('553 د.ل'), findsWidgets);

    await go(tester, '/treasury');
    expect(find.byKey(const Key('screen-treasury')), findsOneWidget);
    expect(find.text('51,000 د.ل'), findsWidgets);
    expect(find.text('45,000 د.ل'), findsWidgets);

    await go(tester, '/reports');
    expect(find.byKey(const Key('screen-reports')), findsOneWidget);
    expect(find.text('ديون لنا + النشط + المصري − ديون علينا'), findsOneWidget);
  });

  testWidgets(
    'P7-06 customers list shows a loading pane until the server answers',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      final gate = Completer<void>();
      (layer.client as FakeApiClient).pauseAccountLists = gate;

      goNow(tester, '/customers');
      await pumpUntilFound(tester, find.byKey(const Key('accounts-loading')));
      expect(find.byKey(const Key('screen-customers')), findsNothing);

      gate.complete();
      (layer.client as FakeApiClient).pauseAccountLists = null;
      await settle(tester);
      expect(find.byKey(const Key('screen-customers')), findsOneWidget);
      expect(find.text('10,635 د.ل'), findsWidgets);
    },
  );

  testWidgets(
    'P7-06 a missing card is an error with retry, not a forbidden pane',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 1400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/missing-card');

      expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
      expect(find.text('العنصر غير موجود'), findsWidgets);
      expect(find.text(AppStrings.retry), findsWidgets);
      expect(find.byKey(ForbiddenPane.paneKey), findsNothing);
    },
  );

  testWidgets('P7-06 the financial ledger is a real empty server page', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');

    expect(find.byKey(const Key('financial-ledger')), findsOneWidget);
    expect(find.text(AppStrings.emptyLedger), findsWidgets);
    expect(
      tester.widget<MoneyText>(find.byKey(const Key('ledger-total-LYD'))).text,
      '0 د.ل',
    );
    expect(
      tester.widget<MoneyText>(find.byKey(const Key('ledger-total-EGP'))).text,
      '0 ج.م',
    );
  });

  testWidgets(
    'P7-06 employee totals shows the server row, then an empty window',
    (tester) async {
      // 🔶 GET /api/admin/employee-totals. The November window is a second
      // canned payload, not a sum of the October row.
      await pumpFakeApp(tester, size: const Size(800, 1600));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/settings/employee-totals');

      expect(find.byKey(EmployeeTotalsScreen.screenKey), findsOneWidget);
      expect(find.text('موظف استلام تجريبي'), findsOneWidget);
      expect(find.text('100 د.ل'), findsWidgets);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(HomeShell.shellKey)),
      );
      container.read(employeeTotalsQueryProvider.notifier).state =
          const EmployeeTotalsQuery(from: '2026-11-01', to: '2026-11-30');
      await settle(tester);

      expect(find.text('موظف استلام تجريبي'), findsNothing);
      expect(find.text('100 د.ل'), findsNothing);
      expect(find.text('0 د.ل'), findsWidgets);
    },
    tags: ['pending-decision'],
  );

  testWidgets('P7-06 employee totals stays on the loading key while paused', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final gate = Completer<void>();
    (layer.client as FakeApiClient).pauseEmployeeTotals = gate;

    goNow(tester, '/settings/employee-totals');
    await pumpUntilFound(tester, find.byKey(EmployeeTotalsScreen.loadingKey));
    expect(find.byKey(EmployeeTotalsScreen.screenKey), findsOneWidget);
    expect(find.text('موظف استلام تجريبي'), findsNothing);

    gate.complete();
    (layer.client as FakeApiClient).pauseEmployeeTotals = null;
    await settle(tester);
    expect(find.text('موظف استلام تجريبي'), findsOneWidget);
  }, tags: ['pending-decision']);

  testWidgets('P7-06 employee totals error offers retry and is not forbidden', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    (layer.client as FakeApiClient).failEmployeeTotalsRemaining = 1;

    await go(tester, '/settings/employee-totals');
    expect(find.byKey(EmployeeTotalsScreen.retryKey), findsOneWidget);
    expect(find.text('تعذر تحميل إجماليات الموظفين.'), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsNothing);

    await tester.tap(find.byKey(EmployeeTotalsScreen.retryKey));
    await settle(tester);
    expect(find.text('موظف استلام تجريبي'), findsOneWidget);
    expect(find.byKey(EmployeeTotalsScreen.retryKey), findsNothing);
  }, tags: ['pending-decision']);

  testWidgets('P7-06 limited admin notifications list is empty', (
    tester,
  ) async {
    // 🔶 recipientUserId. u_2 has no row in the catalog, so the list is empty.
    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');
    await go(tester, '/notifications');

    expect(find.byKey(NotificationsScreen.screenKey), findsOneWidget);
    expect(find.text(AppStrings.noNotifications), findsOneWidget);
    expect(find.text('إشعار المدير'), findsNothing);
  }, tags: ['pending-decision']);

  testWidgets(
    'P7-06 a notifications failure offers retry and is not forbidden',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      (layer.client as FakeApiClient).failNextNotificationListStatus = 503;

      await go(tester, '/notifications');
      expect(find.byKey(NotificationsScreen.retryKey), findsOneWidget);
      expect(find.text('تعذر تحميل الإشعارات.'), findsOneWidget);
      expect(find.byKey(ForbiddenPane.paneKey), findsNothing);

      await tester.tap(find.byKey(NotificationsScreen.retryKey));
      await settle(tester);
      expect(find.text('إشعار المدير'), findsOneWidget);
    },
  );

  testWidgets(
    'P7-07 empty settings tiles show the DEF-012 placeholders and do not close the row',
    (tester) async {
      // DEF-012 is still open. These three sentences are placeholders, not
      // server rows. A Pass needs real rows or an owner decision. This test
      // only locks the current copy so a regression is visible.
      await pumpFakeApp(tester, size: const Size(800, 1400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');

      await go(tester, '/settings/employees');
      expect(
        find.byKey(const Key('screen-settings-employees')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.employeesEmpty), findsOneWidget);

      await go(tester, '/settings/audit');
      expect(find.byKey(const Key('screen-settings-audit')), findsOneWidget);
      expect(find.text(AppStrings.auditEmpty), findsOneWidget);

      await go(tester, '/settings/operations');
      expect(
        find.byKey(const Key('screen-settings-operations')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.operationsEmpty), findsOneWidget);
    },
    tags: ['known-bug'],
  );
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}
