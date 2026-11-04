// Customers and companies share a design, never a calculation (Ali,
// 2026-11-03). Same fixture values give each section its own result, and
// nothing read for one section is reused by the other.
import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/company_card_tone.dart';
import 'package:vib_abdo_company_mobile/features/accounts/customer_card_tone.dart';
import 'package:vib_abdo_company_mobile/features/accounts/ledger_running_balance.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

AccountCardDto _card(int units, String age, {String? label}) =>
    AccountCardDto.fromJson({
      'id': 'same',
      'name': 'نفس الكارت',
      'balanceUnits': units,
      'currency': 'LYD',
      'ageStatus': age,
      'ageStatusLabel': label,
      'version': 1,
    }, AccountSection.companies);

Finder _inside(Key key, String text) =>
    find.descendant(of: find.byKey(key), matching: find.text(text));

void main() {
  test('same card values: each section uses its own function', () {
    // Same colours and words as customers (Ali, 2026-11-03), but the
    // companies' own sign function, independent of age.
    for (final age in ['new', 'warning', 'overdue', 'credit', 'zero']) {
      final debt = _card(320, age);
      expect(companyCardKind(debt.balanceUnits), CompanyCardKind.debt);
      expect(customerBalanceKind(debt.balanceUnits), CustomerBalanceKind.debt);
      expect(
        companyCardKind(_card(-45, age).balanceUnits),
        CompanyCardKind.credit,
      );
      expect(companyCardKind(_card(0, age).balanceUnits), CompanyCardKind.zero);
    }
    expect(companyCardWord(CompanyCardKind.debt), AppStrings.customerDebtWord);
    expect(
      companyCardWord(CompanyCardKind.credit),
      AppStrings.customerCreditWord,
    );
    expect(companyCardWord(CompanyCardKind.zero), isNull);
    expect(companyCardKind(null), CompanyCardKind.unknown);
    // Ledger total heading: the company's trust label only for companies.
    expect(
      companyLedgerHeading(companyLedgerKind(const MoneyValue.known(-45))),
      AppStrings.companyTrust,
    );
    expect(
      companyLedgerHeading(companyLedgerKind(const MoneyValue.known(320))),
      AppStrings.ledgerTotal,
    );
  });

  test('the running balance is a pure function of one ledger', () {
    LedgerEntryDto row(String id, int seq, String type, int amount) =>
        LedgerEntryDto.fromJson({
          'id': id,
          'sequence': seq,
          'type': type,
          'status': 'posted',
          'amountUnits': amount,
        });
    final customers = [row('a', 1, 'debt', 500), row('b', 2, 'payment', 180)];
    final companies = [row('a', 1, 'debt', 100), row('b', 2, 'debt', 25)];
    final c1 = websiteRunningBalances(
      opening: const MoneyValue.known(0),
      items: customers,
    );
    final k1 = websiteRunningBalances(
      opening: const MoneyValue.known(10),
      items: companies,
    );
    final c2 = websiteRunningBalances(
      opening: const MoneyValue.known(0),
      items: customers,
    );
    expect(c1, {'a': 500, 'b': 320});
    expect(k1, {'a': 110, 'b': 135});
    // Computing companies in between did not change the customers result.
    expect(c2, c1);
  });

  testWidgets('list totals come from each section and do not leak', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(
      _inside(const Key('customers-summary-amount'), '10,635 د.ل'),
      findsOneWidget,
    );
    await go(tester, '/companies');
    expect(find.byKey(const Key('customers-summary')), findsNothing);
    expect(
      _inside(const Key('companies-summary-amount'), '1,035 د.ل'),
      findsOneWidget,
    );
    await go(tester, '/customers');
    expect(
      _inside(const Key('customers-summary-amount'), '10,635 د.ل'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a company payment leaves the same-id customer untouched', (
    tester,
  ) async {
    // c_55 exists in both sections with the same id and balance (320).
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(
      _inside(const Key('ledger-header-balance'), '320 د.ل'),
      findsOneWidget,
    );
    await go(tester, '/companies/c_55');
    expect(
      _inside(const Key('ledger-header-balance'), '320 د.ل'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const Key('composer-full')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('composer-full')));
    await tester.pump();
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('full-payment')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('full-payment')));
    await settle(tester);
    expect(
      _inside(const Key('ledger-header-balance'), '0 د.ل'),
      findsOneWidget,
    );
    expect(
      _inside(const Key('ledger-header-kind'), AppStrings.ledgerZeroWord),
      findsOneWidget,
    );
    // Back to the customer with the same id: still its own 320.
    await go(tester, '/customers/c_55');
    await settle(tester);
    expect(
      _inside(const Key('ledger-header-balance'), '320 د.ل'),
      findsOneWidget,
    );
    expect(
      _inside(const Key('ledger-header-kind'), AppStrings.customerDebtWord),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the companies ledger uses the shared table design', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies/c_55');
    // Pinned glossy total with its pill, sticky column names, grid table,
    // ديون preselected and the value field focused.
    expect(find.byKey(const Key('ledger-header-kind')), findsOneWidget);
    expect(find.byKey(const Key('ledger-total-heading')), findsOneWidget);
    expect(find.byKey(const Key('ledger-column-header')), findsOneWidget);
    expect(find.byKey(const Key('ledger-table')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('movement-amount')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.focusNode?.hasFocus ?? field.autofocus, isTrue);
    expect(find.byKey(const Key('ledger-sequence-tx_old')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  });
}
