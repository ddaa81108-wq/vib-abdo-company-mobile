import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  AccountCardDto card({
    required int balance,
    int? days,
    bool system = false,
    AccountSection section = AccountSection.customers,
  }) {
    return AccountCardDto(
      id: 'x',
      name: 'n',
      balanceUnits: MoneyValue.known(balance),
      currency: section.currency,
      debtAgeDays: days,
      systemManaged: system,
    );
  }

  test('website status labels follow DebtAccountsView', () {
    expect(
      websiteCardStatus(AccountSection.customers, card(balance: 10, days: 1)),
      'دين جديد',
    );
    expect(
      websiteCardStatus(AccountSection.customers, card(balance: 10, days: 3)),
      'مرّ عليه 3 أيام',
    );
    expect(
      websiteCardStatus(AccountSection.companies, card(balance: 10, days: 7)),
      'دين متأخر',
    );
    expect(
      websiteCardStatus(AccountSection.customers, card(balance: -5)),
      'أمانة',
    );
    expect(
      websiteCardStatus(AccountSection.customers, card(balance: 0)),
      'حساب صفر',
    );
    expect(
      websiteCardStatus(
        AccountSection.customers,
        card(balance: 10, system: true),
      ),
      'مرتبط تلقائيًا',
    );
    expect(
      websiteCardStatus(
        AccountSection.libyanDeposits,
        card(balance: 4, section: AccountSection.libyanDeposits),
      ),
      'أمانة للعميل',
    );
    expect(
      websiteCardStatus(
        AccountSection.egyptianDeposits,
        card(balance: 4, section: AccountSection.egyptianDeposits),
      ),
      'لصالح المنظومة — دين على العميل',
    );
    final amount = websiteCardAmount(
      const MoneyFormatter(),
      card(balance: -2198),
    );
    expect(amount, '2.198 د.ل');
    expect(amount.contains('-'), isFalse);
  });

  test('card colours follow ownership, not age', () {
    expect(
      websiteCardGradient(AccountSection.customers, 10).colors.first,
      const Color(0xFFBD3B47),
    );
    expect(
      websiteCardGradient(AccountSection.customers, -10).colors.first,
      const Color(0xFF219E6D),
    );
    expect(
      websiteCardGradient(AccountSection.libyanDeposits, 10).colors.first,
      const Color(0xFF219E6D),
    );
    expect(
      websiteCardGradient(AccountSection.egyptianDeposits, 10).colors.first,
      const Color(0xFF219E6D),
    );
    expect(
      websiteCardGradient(AccountSection.customers, 0).colors.first,
      const Color(0xFF343434),
    );
  });

  testWidgets('a long name and لدى chip stay inside the card at 360 x1.3', (
    tester,
  ) async {
    final cards = [
      AccountCardDto(
        id: 'long',
        name: 'مجموعه عصام الشوادفي',
        balanceUnits: const MoneyValue.known(2198),
        currency: Currency.lyd,
        activeAssigneeName: 'الصفير',
        lastActivityAt: DateTime.utc(2026, 10, 18, 12, 3),
        debtAgeDays: 1,
        version: 1,
      ),
      AccountCardDto(
        id: 'trust',
        name: 'أمانة طويلة الاسم للتجربة فقط',
        balanceUnits: const MoneyValue.known(-80),
        currency: Currency.lyd,
        debtAgeDays: 0,
        version: 1,
      ),
    ];
    await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      textScale: 1.3,
      overrides: [
        accountsProvider.overrideWith(
          (ref, section) async => AccountsPage(
            page: Paged(items: cards),
            summary: const AccountsSummaryDto(activeCards: 2),
          ),
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(tester.takeException(), isNull);

    final card = tester.getRect(find.byKey(const Key('account-card-long')));
    final amount = tester.getRect(find.byKey(const Key('account-amount-long')));
    final chip = tester.getRect(find.byKey(const Key('account-assignee-long')));
    final name = tester.getRect(find.text('مجموعه عصام الشوادفي'));
    expect(card.top, lessThanOrEqualTo(name.top));
    expect(name.bottom, lessThanOrEqualTo(amount.top + 1));
    expect(amount.bottom, lessThanOrEqualTo(card.bottom));
    expect(chip.left, greaterThanOrEqualTo(card.left - 1));
    expect(chip.right, lessThanOrEqualTo(card.right + 1));
    expect(chip.top, greaterThanOrEqualTo(card.top - 1));
    expect(find.text('2.198 د.ل'), findsOneWidget);
    expect(find.text('لدى: الصفير'), findsOneWidget);
    expect(find.textContaining('آخر حركة:'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
