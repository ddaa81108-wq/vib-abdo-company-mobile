import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_ledger_tone.dart';
import 'package:flutter_api_layer/api_layer.dart';

void main() {
  test('deposit cards use the website sign colours and words', () {
    expect(depositCardGloss(40), depositCardGreen);
    expect(depositCardGloss(-10), depositCardRed);
    expect(depositCardGloss(0), depositCardZero);
    expect(depositCardLabel(AccountSection.libyanDeposits, 40), 'أمانة للعميل');
    expect(
      depositCardLabel(AccountSection.libyanDeposits, -5),
      'دين على العميل',
    );
    expect(
      depositCardLabel(AccountSection.egyptianDeposits, 40),
      'لصالح المنظومة — دين على العميل',
    );
    expect(
      depositCardLabel(AccountSection.egyptianDeposits, -5),
      'دين علينا للعميل',
    );
    expect(depositCardLabel(AccountSection.libyanDeposits, 0), 'حساب صفر');
  });

  test('ledger totals are gold except the Egyptian sign colours', () {
    expect(websiteLedgerGloss(AccountSection.customers, 20), websiteLedgerGold);
    expect(
      websiteLedgerGloss(AccountSection.libyanDeposits, -4),
      websiteLedgerGold,
    );
    expect(
      websiteLedgerGloss(AccountSection.egyptianDeposits, 8),
      websiteLedgerGreen,
    );
    expect(
      websiteLedgerGloss(AccountSection.egyptianDeposits, -8),
      websiteLedgerRed,
    );
    expect(
      websiteLedgerGloss(AccountSection.egyptianDeposits, 0),
      websiteLedgerSlate,
    );
  });
}
