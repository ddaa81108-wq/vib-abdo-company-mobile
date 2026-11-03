import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';

/// Company cards (قسم الشركات). Kept apart from the customers' tone on
/// purpose: the two sections never share a rule (Ali, 2026-11-03).
///
/// The website's company card class (`DebtAccountsView` `te()`): a negative
/// balance is `credit-balance`, zero is `zero-balance`, otherwise the debt
/// age class. The server's `ageStatus` wins when it is sent; staging sends
/// only `debtAgeDays`, so the website's own split applies then
/// (`(debtAgeDays ?? 0) >= 7` overdue, `>= 3` warning, else new). Display
/// only; no money is computed.
enum CompanyCardState { newDebt, warning, overdue, credit, zero, unknown }

CompanyCardState companyCardState(AccountCardDto card) {
  final units = card.balanceUnits?.asInt;
  if (units == null) return CompanyCardState.unknown;
  if (units < 0) return CompanyCardState.credit;
  if (units == 0) return CompanyCardState.zero;
  switch (card.ageStatus) {
    case 'overdue':
      return CompanyCardState.overdue;
    case 'warning':
      return CompanyCardState.warning;
    case 'new':
      return CompanyCardState.newDebt;
  }
  final days = card.debtAgeDays ?? 0;
  if (days >= 7) return CompanyCardState.overdue;
  if (days >= 3) return CompanyCardState.warning;
  return CompanyCardState.newDebt;
}

/// The state word on a company card: the server's own label when it sent
/// one (as on every card, P7-06), else the website's company label (`re()`):
/// أمانة / حساب صفر / دين متأخر / مرّ عليه 3 أيام / دين جديد.
String? companyCardWord(AccountCardDto card) {
  final server = card.ageStatusLabel;
  if (server != null && server.isNotEmpty) return server;
  return switch (companyCardState(card)) {
    CompanyCardState.credit => AppStrings.customerCreditWord,
    CompanyCardState.zero => AppStrings.zeroAccount,
    CompanyCardState.overdue => AppStrings.overdue,
    CompanyCardState.warning => AppStrings.warningAge,
    CompanyCardState.newDebt => AppStrings.newDebt,
    CompanyCardState.unknown => null,
  };
}

Gloss _fromGradient(LinearGradient gradient, Color ink) {
  final top = gradient.colors.first;
  final bottom = gradient.colors.last;
  final middle = gradient.colors[gradient.colors.length ~/ 2];
  return Gloss(
    top: top,
    bottom: bottom,
    border: Color.lerp(top, Colors.white, 0.35)!,
    glow: middle.withValues(alpha: 0.4),
    ink: ink,
    amount: ink,
  );
}

/// Glossy fill per state with the website's CSS age colours; zero is the
/// glossy black card.
Gloss companyCardGloss(BuildContext context, CompanyCardState state) {
  final look = context.look;
  final colors = context.statusColors;
  return switch (state) {
    CompanyCardState.newDebt => _fromGradient(colors.newDebt, colors.onStatus),
    CompanyCardState.warning => _fromGradient(
      colors.warningDebt,
      colors.onStatus,
    ),
    CompanyCardState.overdue => _fromGradient(
      colors.overdueDebt,
      colors.onStatus,
    ),
    CompanyCardState.credit => _fromGradient(
      colors.creditBalance,
      colors.onStatus,
    ),
    CompanyCardState.zero => look.glossZero,
    CompanyCardState.unknown => look.glossGrey,
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
