import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';

/// Company cards (قسم الشركات). Kept apart from the customers' tone on
/// purpose: the two sections never share a rule (Ali, 2026-11-03).
///
/// The website's company card class (`DebtAccountsView` `te()`): a negative
/// balance is `credit-balance`, zero is `zero-balance`, otherwise the debt
/// age class. The app takes the age from the server's `ageStatus` (it does
/// not apply the 3/7-day thresholds itself). Display only.
enum CompanyCardState { newDebt, warning, overdue, credit, zero, unknown }

CompanyCardState companyCardState(AccountCardDto card) {
  final units = card.balanceUnits?.asInt;
  if (units == null) return CompanyCardState.unknown;
  if (units < 0) return CompanyCardState.credit;
  if (units == 0) return CompanyCardState.zero;
  return switch (card.ageStatus) {
    'overdue' => CompanyCardState.overdue,
    'warning' => CompanyCardState.warning,
    'new' => CompanyCardState.newDebt,
    _ => CompanyCardState.unknown,
  };
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
