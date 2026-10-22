import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/performance/history_window.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import '../../support/phase7_nav.dart';
import '../../support/pump_app.dart';

/// Phase 8. Real screens and providers. Transport is [FakeApiClient] only.
///
/// Each passing case reads the field back from the same client and compares
/// the on-screen text with [MoneyFormatter] at the documented scale 0.
/// A skipped case names the defect that the website has not confirmed.
void main() {
  const tag = 'reconciliation';
  final money = MoneyFormatter();

  tearDown(() {
    HistoryWindow.trimEnabled = HistoryWindow.trimEnabledFromEnvironment;
  });

  testWidgets('section totals and the sample card match the formatted server fields', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    await _expectSummary(
      tester,
      layer,
      AccountSection.customers,
      const Key('screen-customers'),
      Currency.lyd,
      money,
    );
    await _expectSummary(
      tester,
      layer,
      AccountSection.companies,
      const Key('screen-companies'),
      Currency.lyd,
      money,
    );
    await _expectSummary(
      tester,
      layer,
      AccountSection.libyanDeposits,
      const Key('screen-libyan-deposits'),
      Currency.lyd,
      money,
    );
    await _expectSummary(
      tester,
      layer,
      AccountSection.egyptianDeposits,
      const Key('screen-egyptian-deposits'),
      Currency.egp,
      money,
    );

    await go(tester, '/customers/c_55');
    final card = await _flushed(
      tester,
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    expect(card.balanceUnits, isNotNull);
    final balance = _fmt(money, card.balanceUnits, card.currency);
    expect(balance, '320 د.ل');
    expect(_inside(const Key('ledger-header-balance'), balance), findsOneWidget);

    await go(tester, '/purchases');
    final book = await _flushed(
      tester,
      () => layer.purchases.list(PurchaseBook.alBayan),
    );
    final totals = book.lifetimeTotals!;
    expect(
      _inside(
        const Key('purchases-lifetime'),
        _fmt(money, totals.remainingUnits, Currency.lyd),
      ),
      findsOneWidget,
    );
    expect(
      _inside(
        const Key('purchases-lifetime'),
        _fmt(money, totals.resultUnits, Currency.lyd),
      ),
      findsOneWidget,
    );
    expect(
      _inside(
        const Key('purchases-lifetime'),
        _fmt(money, totals.paidUnits, Currency.lyd),
      ),
      findsOneWidget,
    );
    expect(_fmt(money, totals.remainingUnits, Currency.lyd), '2,553 د.ل');

    await go(tester, '/treasury');
    final treasury = await _flushed(tester, () => layer.treasury.summary());
    expect(
      _inside(
        const Key('screen-treasury'),
        _fmt(money, treasury.netUnits, Currency.lyd),
      ),
      findsOneWidget,
    );
    expect(
      _inside(
        const Key('screen-treasury'),
        _fmt(money, treasury.egyptianSourceUnits, Currency.egp),
      ),
      findsOneWidget,
    );
    expect(_fmt(money, treasury.netUnits, Currency.lyd), '51,000 د.ل');
    expect(
      _fmt(money, treasury.egyptianSourceUnits, Currency.egp),
      '95,000 ج.م',
    );

    await go(tester, '/collections');
    final collections = await _flushed(
      tester,
      () => layer.collections.overview(),
    );
    for (final units in [
      collections.collectedUnits,
      collections.dayTotalUnits,
      collections.cashOutstandingUnits,
    ]) {
      expect(
        _inside(
          const Key('screen-collections'),
          _fmt(money, units, Currency.lyd),
        ),
        findsWidgets,
      );
    }
    expect(_fmt(money, collections.dayTotalUnits, Currency.lyd), '100 د.ل');
    expect(
      _fmt(money, collections.cashOutstandingUnits, Currency.lyd),
      '250 د.ل',
    );
    expect(tester.takeException(), isNull);
  }, tags: [tag]);

  testWidgets('partial and full payment headers match the refetched card', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    await tester.ensureVisible(find.byKey(const Key('add-payment')));
    await tester.tap(find.byKey(const Key('add-payment')));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('movement-amount')),
        matching: find.byType(TextField),
      ),
      '100',
    );
    await tester.tap(find.byKey(const Key('save-movement')));
    await settle(tester);

    final afterPartial = await _flushed(
      tester,
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    expect(afterPartial.balanceUnits, isNotNull);
    final partialText = _fmt(
      money,
      afterPartial.balanceUnits,
      afterPartial.currency,
    );
    expect(
      _inside(const Key('ledger-header-balance'), partialText),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.tap(find.byKey(const Key('full-payment')));
    await settle(tester);
    final afterFull = await _flushed(
      tester,
      () => layer.accounts.get(AccountSection.customers, 'c_55'),
    );
    expect(afterFull.balanceUnits, isNotNull);
    final fullText = _fmt(money, afterFull.balanceUnits, afterFull.currency);
    expect(fullText, '0 د.ل');
    expect(_inside(const Key('ledger-header-balance'), fullText), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, tags: [tag]);

  testWidgets('a trimmed account window keeps the server total', (tester) async {
    HistoryWindow.trimEnabled = true;
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      fakeDataset: FakeDataset.large,
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');

    await tester.ensureVisible(find.byKey(const Key('load-more-accounts')));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('load-more-accounts')));
      await settle(tester);
    }

    final page = await _flushed(
      tester,
      () => layer.accounts.list(AccountSection.customers),
    );
    final total = _fmt(money, page.summary.totalDebtUnits, Currency.lyd);
    final net = _fmt(money, page.summary.netBalanceUnits, Currency.lyd);
    expect(total, '12,800,000 د.ل');
    expect(net, total);
    expect(_inside(const Key('screen-customers'), total), findsWidgets);

    final visible = HistoryWindowTrace.accountWindow;
    expect(visible.length, lessThan(FakeLargeCatalog.customerCount));
    expect(visible.length, 120);
    var visibleSum = 0;
    for (final id in visible) {
      final index = int.parse(id.substring(3));
      visibleSum +=
          FakeLargeCatalog.accountCard('customers', index)['balanceUnits']
              as int;
    }
    expect(visibleSum, isNot(page.summary.totalDebtUnits?.asInt));
    expect(tester.takeException(), isNull);
  }, tags: [tag]);

  testWidgets('a large integer card is grouped and not rounded', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    fake.accountNextCursor = 'extra';
    fake.accountNextItems = [
      {'id': 'big', 'name': 'مبلغ كبير', 'balanceUnits': 1250000000},
      {'id': 'edge', 'name': 'حافة التقريب', 'balanceUnits': 999999995},
    ];
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.ensureVisible(find.byKey(const Key('load-more-accounts')));
    await tester.tap(find.byKey(const Key('load-more-accounts')));
    await settle(tester);

    final page = await _flushed(
      tester,
      () => layer.accounts.list(AccountSection.customers),
    );
    final total = _fmt(money, page.summary.totalDebtUnits, Currency.lyd);
    expect(_inside(const Key('screen-customers'), total), findsWidgets);
    expect(
      _inside(const Key('screen-customers'), money.format(1250000000, Currency.lyd)),
      findsOneWidget,
    );
    expect(
      _inside(const Key('screen-customers'), money.format(999999995, Currency.lyd)),
      findsOneWidget,
    );
    expect(find.text('1,000,000,000 د.ل'), findsNothing);
    expect(money.format(999999995, Currency.lyd), '999,999,995 د.ل');
    expect(tester.takeException(), isNull);
  }, tags: [tag]);

  testWidgets('a fractional money field is rejected and not rounded on screen', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    final fake = layer.client as FakeApiClient;
    fake.accountNextCursor = 'frac';
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    final shown = money.format(10635, Currency.lyd);
    expect(_inside(const Key('screen-customers'), shown), findsWidgets);

    for (final fraction in [10.005, 0.995, 1.995]) {
      fake.accountNextCursor = 'frac';
      fake.accountNextItems = [
        {'id': 'frac', 'name': 'كسر', 'balanceUnits': fraction},
      ];
      final page = await _flushed(
        tester,
        () => layer.accounts.list(AccountSection.customers, cursor: 'frac'),
      );
      final bad = page.page.items.single;
      expect(bad.balanceUnits!.isInvalid, isTrue);
      expect(bad.balanceUnits!.asInt, isNull);
      expect(bad.balanceUnits!.asInt, isNot(0));
      expect(bad.balanceUnits!.asInt, isNot(2));
      expect(bad.balanceUnits!.asInt, isNot(10));
      expect(
        layer.money.formatOrDash(bad.balanceUnits, Currency.lyd),
        'مبلغ غير صالح',
      );
    }

    await tester.ensureVisible(find.byKey(const Key('load-more-accounts')));
    await tester.tap(find.byKey(const Key('load-more-accounts')));
    await settle(tester);
    expect(find.text('مبلغ غير صالح'), findsWidgets);
    expect(find.text('10 د.ل'), findsNothing);
    expect(find.text('1 د.ل'), findsNothing);
    expect(find.text('2 د.ل'), findsNothing);
    expect(_inside(const Key('screen-customers'), shown), findsWidgets);
    expect(tester.takeException(), isNull);
  }, tags: [tag]);

  test('DEF-028 the fake delta is not a website balance', () {
    markTestSkipped(
      'DEF-028. FakeApiClient stores previous - inputValue. '
      'The screen test compares the header with the refetched field only.',
    );
  }, tags: [tag]);

  test('DEF-029 website display precision is unconfirmed', () {
    markTestSkipped(
      'DEF-029. moneyUnitScale 0 is unconfirmed and P0-04 is not run. '
      'No website fraction is available to compare.',
    );
  }, tags: [tag]);

  test('DEF-030 summary scope under search and hidden rows is unknown', () {
    markTestSkipped(
      'DEF-030. The strip shows summary. Whether q, filter, or hidden rows '
      'change that object is not written down.',
    );
  }, tags: [tag]);

  test('DEF-031 the cached payment ceiling is not a confirmed server rule', () {
    markTestSkipped(
      'DEF-031. The dialog compares the typed amount with the cached '
      'balanceUnits. The real server rule is still unknown.',
    );
  }, tags: [tag]);

  testWidgets('DEF-032 a missing Egyptian rate keeps the server EGP amount', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    final fake = layer.client as FakeApiClient;
    fake.treasuryTotalsPatch = const <String, Object?>{'egyptianRate': null};
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/treasury');
    expect(find.text('95,000 ج.م'), findsWidgets);
    expect(find.text('يلزم سعر تحويل معتمد'), findsOneWidget);
    expect(find.byKey(const Key('rate-missing')), findsOneWidget);
    expect(find.text('10,000 د.ل'), findsNothing);
    expect(find.text('0 ج.م'), findsNothing);
    expect(find.text('0 د.ل'), findsNothing);
    final summary = await _flushed(tester, () => layer.treasury.summary());
    expect(summary.egyptianRate, isNull);
    expect(summary.rateMissing, isTrue);
    expect(summary.egyptianSourceUnits?.asInt, 95000);
    expect(tester.takeException(), isNull);
  }, tags: [tag]);

  test('DEF-033 Vodafone currency is an assumption', () {
    markTestSkipped(
      'DEF-033. The day line prints ج.م from vodafoneCurrencyAssumption. '
      'The website currency is not confirmed.',
    );
  }, tags: [tag]);

  test('DEF-034 purchase lifetime key names are unconfirmed', () {
    markTestSkipped(
      'DEF-034. The screen reads resultUnits, paidUnits, and remainingUnits. '
      'Other key names would stay off screen.',
    );
  }, tags: [tag]);

  test('DEF-035 collections currency is fixed to LYD in the client', () {
    markTestSkipped(
      'DEF-035. CollectionsOverviewDto.currency always returns LYD. '
      'No server currency field is read. ${AppStrings.collected} stays on that symbol.',
    );
  }, tags: [tag]);

  testWidgets('DEF-036 one fractional field is invalid and the page stays', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    fake.accountNextCursor = 'frac';
    fake.accountNextItems = [
      {'id': 'frac', 'name': 'كسر', 'balanceUnits': 1.995},
    ];
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    final shown = money.format(10635, Currency.lyd);
    expect(_inside(const Key('screen-customers'), shown), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('load-more-accounts')));
    await tester.tap(find.byKey(const Key('load-more-accounts')));
    await settle(tester);
    expect(find.text('مبلغ غير صالح'), findsWidgets);
    expect(find.text('2 د.ل'), findsNothing);
    expect(find.text('1 د.ل'), findsNothing);
    expect(_inside(const Key('screen-customers'), shown), findsWidgets);
    final page = await _flushed(
      tester,
      () => layer.accounts.list(AccountSection.customers, cursor: 'frac'),
    );
    expect(page.page.items.single.balanceUnits!.isInvalid, isTrue);
    expect(page.summary.totalDebtUnits?.asInt, 10635);
    expect(tester.takeException(), isNull);
  }, tags: [tag]);
}

Future<void> _expectSummary(
  WidgetTester tester,
  ApiLayer layer,
  AccountSection section,
  Key screen,
  Currency currency,
  MoneyFormatter money,
) async {
  await go(tester, '/${section.path}');
  final page = await _flushed(tester, () => layer.accounts.list(section));
  final total = _fmt(money, page.summary.totalDebtUnits, currency);
  final net = _fmt(money, page.summary.netBalanceUnits, currency);
  expect(_inside(screen, total), findsWidgets);
  expect(_inside(screen, net), findsWidgets);
}

String _fmt(MoneyFormatter money, MoneyValue? value, Currency currency) {
  expect(value, isNotNull);
  expect(value!.isValid, isTrue);
  return money.format(value.asInt!, currency);
}

Finder _inside(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}

/// The fake answers on a zero-delay timer. Awaiting that future without
/// pumping deadlocks the test binding, and one pump can run before the timer
/// is armed. Pump until the read settles, then return or rethrow it.
Future<T> _flushed<T>(WidgetTester tester, Future<T> Function() start) async {
  final future = start();
  Object? error;
  StackTrace? stack;
  var done = false;
  T? value;
  future.then(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object thrown, StackTrace thrownStack) {
      error = thrown;
      stack = thrownStack;
      done = true;
    },
  );
  for (var i = 0; i < 30 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  if (!done) {
    fail('the fake read did not complete');
  }
  if (error != null) {
    Error.throwWithStackTrace(error!, stack!);
  }
  return value as T;
}
