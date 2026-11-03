import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';

/// Company cards (قسم الشركات). Kept apart from the customers' functions on
/// purpose: the two sections never share a rule (Ali, 2026-11-03).
///
/// Ali, 2026-11-03: company cards use the same colours and words as the
/// customer cards, from the sign of the company's own server balance only:
/// دين glossy red, أمانة glossy green, zero glossy black (no word, as on a
/// customer card). Display only; no money is computed.
enum CompanyCardKind { debt, credit, zero, unknown }

CompanyCardKind companyCardKind(MoneyValue? balance) {
  final units = balance?.asInt;
  if (units == null) return CompanyCardKind.unknown;
  if (units > 0) return CompanyCardKind.debt;
  if (units < 0) return CompanyCardKind.credit;
  return CompanyCardKind.zero;
}

/// The word under the name: دين / أمانة, nothing for zero (like customers).
String? companyCardWord(CompanyCardKind kind) => switch (kind) {
  CompanyCardKind.debt => AppStrings.customerDebtWord,
  CompanyCardKind.credit => AppStrings.customerCreditWord,
  _ => null,
};

Gloss companyCardGloss(BuildContext context, CompanyCardKind kind) {
  final look = context.look;
  return switch (kind) {
    CompanyCardKind.debt => look.glossDebt,
    CompanyCardKind.credit => look.glossCredit,
    CompanyCardKind.zero => look.glossZero,
    CompanyCardKind.unknown => look.glossGrey,
  };
}

/// The companies ledger total card: the state from the sign of the server
/// balance only (the website's `ke()` footer: `< 0` is the company's trust,
/// `0` zero, otherwise the current debt). Separate from the customers'
/// rule on purpose.
enum CompanyLedgerKind { debt, credit, zero, unknown }

CompanyLedgerKind companyLedgerKind(MoneyValue? balance) {
  final units = balance?.asInt;
  if (units == null) return CompanyLedgerKind.unknown;
  if (units > 0) return CompanyLedgerKind.debt;
  if (units < 0) return CompanyLedgerKind.credit;
  return CompanyLedgerKind.zero;
}

/// The heading over the figure: «أمانة للشركة» for a credit (website
/// `trustLabel`), otherwise «إجمالي الدين الحالي».
String companyLedgerHeading(CompanyLedgerKind kind) =>
    kind == CompanyLedgerKind.credit
    ? AppStrings.companyTrust
    : AppStrings.ledgerTotal;
