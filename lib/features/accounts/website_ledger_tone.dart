import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';

/// Website ledger footer (`account-balance-colors.css`).
///
/// Customers, companies, and Libyan deposits use the gold total.
/// Egyptian deposits stay green for a positive balance (لصالح المنظومة),
/// red for a negative balance (دين علينا), and slate at zero.
const websiteLedgerGold = Gloss(
  top: Color(0xFFFFF8CC),
  bottom: Color(0xFFE7AE12),
  border: Color(0xFFFFEDAB),
  glow: Color(0x66E7AE12),
  ink: Color(0xFF211600),
  amount: Color(0xFF211600),
  sheen: 0.4,
);

const websiteLedgerGreen = Gloss(
  top: Color(0xFF1EB47B),
  bottom: Color(0xFF087443),
  border: Color(0xFF8EE0B6),
  glow: Color(0x661EB47B),
  ink: Color(0xFFFFFFFF),
  amount: Color(0xFFFFFFFF),
  sheen: 0.16,
);

const websiteLedgerRed = Gloss(
  top: Color(0xFFEF5266),
  bottom: Color(0xFFA61E2A),
  border: Color(0xFFF5A3AE),
  glow: Color(0x66EF5266),
  ink: Color(0xFFFFFFFF),
  amount: Color(0xFFFFFFFF),
  sheen: 0.16,
);

const websiteLedgerSlate = Gloss(
  top: Color(0xFF475569),
  bottom: Color(0xFF334155),
  border: Color(0xFF94A3B8),
  glow: Color(0x66334155),
  ink: Color(0xFFFFFFFF),
  amount: Color(0xFFFFFFFF),
  sheen: 0.12,
);

Gloss websiteLedgerGloss(AccountSection section, int? units) {
  if (section != AccountSection.egyptianDeposits) return websiteLedgerGold;
  if (units == null || units == 0) return websiteLedgerSlate;
  return units > 0 ? websiteLedgerGreen : websiteLedgerRed;
}

/// Deposit list cards (`account-balance-colors.css`).
///
/// A positive balance is green and a negative balance is red in both
/// deposit sections. Debt cards keep their own palette, so a debt and a
/// deposit of the same sign are not the same colour.
const depositCardGreen = Gloss(
  top: Color(0xFF219E6D),
  bottom: Color(0xFF092B20),
  border: Color(0xFF65DBA3),
  glow: Color(0x66219E6D),
  ink: Color(0xFFFFFFFF),
  amount: Color(0xFFFFFFFF),
  sheen: 0.18,
);

const depositCardRed = Gloss(
  top: Color(0xFFBD3B47),
  bottom: Color(0xFF350D16),
  border: Color(0xFFF08895),
  glow: Color(0x66BD3B47),
  ink: Color(0xFFFFFFFF),
  amount: Color(0xFFFFFFFF),
  sheen: 0.18,
);

const depositCardZero = Gloss(
  top: Color(0xFF343434),
  bottom: Color(0xFF080808),
  border: Color(0xFF928B79),
  glow: Color(0x66080808),
  ink: Color(0xFFFFFFFF),
  amount: Color(0xFFFFFFFF),
  sheen: 0.12,
);

Gloss depositCardGloss(int? units) {
  if (units == null || units == 0) return depositCardZero;
  return units > 0 ? depositCardGreen : depositCardRed;
}

/// Website ledger footer heading (`LedgerTotal.tsx` lines 8–17).
///
/// Deposits use the sign labels, and «الحساب صفر» at zero. Customers and
/// companies use the trust label only when the balance is negative.
String websiteLedgerTotalLabel(AccountSection section, int? units) {
  final deposits =
      section == AccountSection.libyanDeposits ||
      section == AccountSection.egyptianDeposits;
  if (deposits) {
    if (units == null) return AppStrings.ledgerDepositTotal;
    if (units == 0) return 'الحساب صفر';
    return depositCardLabel(section, units);
  }
  if (units != null && units < 0) {
    return section == AccountSection.companies
        ? AppStrings.companyTrust
        : AppStrings.trustCustomer;
  }
  return AppStrings.ledgerTotal;
}

/// Short word beside a deposit total: أمانة only for a positive Libyan
/// balance. Every other non-zero deposit balance is دين.
String? depositLedgerKindWord(AccountSection section, int? units) {
  if (units == null || units == 0) return null;
  if (section == AccountSection.libyanDeposits && units > 0) {
    return AppStrings.customerCreditWord;
  }
  return AppStrings.customerDebtWord;
}

/// The words on a website deposit card, from the sign only.
String depositCardLabel(AccountSection section, int? units) {
  if (units == null || units == 0) return 'حساب صفر';
  if (section == AccountSection.egyptianDeposits) {
    return units > 0 ? 'لصالح المنظومة — دين على العميل' : 'دين علينا للعميل';
  }
  return units > 0 ? 'أمانة للعميل' : 'دين على العميل';
}
