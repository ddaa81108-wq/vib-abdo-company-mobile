import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/presentation.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// Server money is displayed through [MoneyFormatter]. These tests do not
/// add, subtract, or derive one fixture field from another.
void main() {
  test('boundaries format the server integer and nothing else', () {
    final money = MoneyFormatter();
    expect(money.format(0, Currency.lyd), '0 د.ل');
    expect(money.formatOrDash(null, Currency.lyd), '—');
    expect(money.format(1250000, Currency.lyd), '1,250,000 د.ل');
    expect(money.format(-80, Currency.lyd), '-80 د.ل');
    expect(money.format(3050, Currency.egp), '3,050 ج.م');
    expect(money.format(8950, Currency.egp), '8,950 ج.م');
    expect(money.format(10635, Currency.lyd), '10,635 د.ل');
  });

  test('unit scale 3 only cuts digits', () {
    // 🔶 unitScale is proposed. The app default stays 0. 8950 is not divided.
    final money = MoneyFormatter(unitScale: 3);
    expect(money.format(8950, Currency.egp), '8.950 ج.م');
    expect(money.format(0, Currency.lyd), '0.000 د.ل');
  }, tags: ['pending-decision']);

  test('a missing zero label falls back, and a server label wins', () {
    // Owner decision still open: how debt is described at zero. Today the
    // server label wins. حساب صفر is only the fallback when that label is
    // absent and ageStatus is zero.
    final omitted = ageVisual(
      colors: AppStatusColors.light,
      ageStatus: 'zero',
      section: AccountSection.customers,
      serverLabel: null,
    );
    expect(omitted.label, AppStrings.zeroAccount);

    const serverLabel = 'منذ 0 أيام';
    final supplied = ageVisual(
      colors: AppStatusColors.light,
      ageStatus: 'zero',
      section: AccountSection.customers,
      serverLabel: serverLabel,
    );
    expect(supplied.label, serverLabel);
    expect(supplied.label, isNot(AppStrings.zeroAccount));
  }, tags: ['pending-decision']);

  test('masraweya work and remaining are the stored fields', () async {
    // 3050 and 8950 are literals. This does not compute 10000 - 3050.
    final layer = _layer();
    await layer.session.login(username: 'admin.demo', password: 'x');
    final day = await layer.masraweya.getDay();
    expect(day.previousValueUnits, 10000);
    expect(day.purchasesUnits, 2000);
    expect(day.workTotalUnits, 3050);
    expect(day.remainingUnits, 8950);
  });

  test('account summaries and payroll remaining are stored literals', () async {
    // Does not compute 10635 - 320, or 1500 + 50 - 300.
    final layer = _layer();
    await layer.session.login(username: 'admin.demo', password: 'x');
    final customers = await layer.accounts.list(AccountSection.customers);
    expect(customers.summary.netBalanceUnits, 10635);
    expect(customers.summary.totalDebtUnits, 10635);
    final companies = await layer.accounts.list(AccountSection.companies);
    expect(companies.summary.netBalanceUnits, 1035);
    final libyan = await layer.accounts.list(AccountSection.libyanDeposits);
    expect(libyan.summary.netBalanceUnits, 695);
    final egyptian = await layer.accounts.list(AccountSection.egyptianDeposits);
    expect(egyptian.summary.netBalanceUnits, 23750);

    final payroll = await layer.collections.payroll();
    expect(
      payroll.employees
          .firstWhere((row) => row.userId == 'u_12')
          .remainingUnits,
      1250,
    );
    expect(
      payroll.employees
          .firstWhere((row) => row.userId == 'u_20')
          .remainingUnits,
      2580,
    );

    final purchases = await layer.purchases.list(PurchaseBook.alBayan);
    expect(purchases.lifetimeTotals?.remainingUnits, 2553);
    expect(purchases.page.items.single.entries.single.remainingUnits, 553);
  });

  testWidgets('P7-06 the zero card shows the server age label', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');

    expect(find.text('منذ 0 أيام'), findsWidgets);
    expect(find.text(AppStrings.zeroAccount), findsNothing);
    expect(find.text('0 د.ل'), findsWidgets);
  }, tags: ['pending-decision']);

  testWidgets(
    'payroll remaining on the collections screen matches the server',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 2600));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');

      await tester.ensureVisible(find.byKey(const Key('payroll-u_12')));
      expect(_inside(const Key('payroll-u_12'), '1,250 د.ل'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('payroll-u_20')));
      expect(_inside(const Key('payroll-u_20'), '2,580 د.ل'), findsOneWidget);
    },
  );

  testWidgets(
    'DEF-016 a full payment leaves the home debt row at the stored zero',
    (tester) async {
      // Decided: the row stays, and the balance is the next server value.
      await pumpFakeApp(tester, size: const Size(800, 2200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers/c_55');
      await tester.ensureVisible(find.byKey(const Key('full-payment')));
      await tester.tap(find.byKey(const Key('full-payment')));
      await settle(tester);

      await go(tester, '/');
      expect(find.byKey(const Key('old-debt-c_55')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('old-debt-c_55')),
          matching: find.textContaining('0 د.ل'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('old-debt-c_55')),
          matching: find.textContaining('320 د.ل'),
        ),
        findsNothing,
      );
    },
  );
}

ApiLayer _layer() {
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(layer.dispose);
  return layer;
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}
