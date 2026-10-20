import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import 'strings.dart';
import 'theme.dart';

/// Badge text from the server count. 0 draws nothing. 99 and above draw "99".
String? badgeLabel(int? count) {
  if (count == null || count <= 0) return null;
  if (count >= 99) return '99';
  return '$count';
}

String formatIsoDate(DateTime? value) {
  if (value == null) return AppStrings.dash;
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Arabic count for a server day integer. This is not a debt-age status.
///
/// 1 → يوم، 2 → يومان، 3–10 → أيام، every other count → يومًا.
String sinceDays(int? days) {
  if (days == null) return AppStrings.dash;
  if (days == 1) return '${AppStrings.sinceDays} ${AppStrings.dayOne}';
  if (days == 2) return '${AppStrings.sinceDays} ${AppStrings.dayTwo}';
  final unit = days.abs() >= 3 && days.abs() <= 10
      ? AppStrings.days
      : AppStrings.dayMany;
  return '${AppStrings.sinceDays} $days $unit';
}

/// One age phrase for a card or a ticker row.
///
/// The contract's age words are [serverLabel] (`ageStatusLabel`). Colour and
/// that label come from the server status; [debtAgeDays] is only a raw count.
/// The count is not printed beside the label, and it is not turned into a
/// 3/7-day status. It is formatted only when the server sent no label and no
/// status name, so the row still has a single age.
String? singleAgeText({
  String? serverLabel,
  String? ageStatus,
  AccountSection? section,
  int? debtAgeDays,
}) {
  final ready = serverLabel?.trim();
  if (ready != null && ready.isNotEmpty) return serverLabel;
  final named = _fallbackLabel(ageStatus, section);
  if (named != null) return named;
  if (debtAgeDays != null) return sinceDays(debtAgeDays);
  return null;
}

/// Colour and label come from the server [ageStatus] only.
/// A missing status stays neutral: no gradient and no status name.
class AgeVisual {
  const AgeVisual({this.gradient, this.flat, this.accent, this.label});

  final LinearGradient? gradient;
  final Color? flat;
  final Color? accent;
  final String? label;

  bool get colored => gradient != null || flat != null;
}

AgeVisual ageVisual({
  required AppStatusColors colors,
  required String? ageStatus,
  required AccountSection? section,
  String? serverLabel,
}) {
  final label = (serverLabel != null && serverLabel.isNotEmpty)
      ? serverLabel
      : _fallbackLabel(ageStatus, section);
  return switch (ageStatus) {
    'new' => AgeVisual(
      gradient: colors.newDebt,
      flat: colors.flatNew,
      accent: colors.accentNew,
      label: label,
    ),
    'warning' => AgeVisual(
      gradient: colors.warningDebt,
      flat: colors.flatWarning,
      accent: colors.accentWarning,
      label: label,
    ),
    'overdue' => AgeVisual(
      gradient: colors.overdueDebt,
      flat: colors.flatOverdue,
      accent: colors.accentOverdue,
      label: label,
    ),
    'zero' => AgeVisual(
      gradient: colors.zeroBalance,
      flat: colors.flatZero,
      accent: colors.accentZero,
      label: label,
    ),
    'credit' => AgeVisual(
      gradient: colors.creditBalance,
      flat: colors.flatCredit,
      accent: colors.accentCredit,
      label: label,
    ),
    _ => const AgeVisual(),
  };
}

String? _fallbackLabel(String? ageStatus, AccountSection? section) {
  if (section == AccountSection.libyanDeposits) {
    return switch (ageStatus) {
      'credit' => AppStrings.trustCustomer,
      'overdue' => AppStrings.debtOnCustomer,
      'zero' => AppStrings.zeroAccount,
      _ => null,
    };
  }
  if (section == AccountSection.egyptianDeposits) {
    return switch (ageStatus) {
      'new' => AppStrings.forOrg,
      'overdue' => AppStrings.debtOnOrg,
      'zero' => AppStrings.zeroAccount,
      _ => null,
    };
  }
  return switch (ageStatus) {
    'credit' => AppStrings.trust,
    'zero' => AppStrings.zeroAccount,
    'overdue' => AppStrings.overdue,
    'warning' => AppStrings.warningAge,
    'new' => AppStrings.newDebt,
    _ => null,
  };
}

/// Age colours are the same hex at every width. The tablet flat palette is not
/// substituted for the phone/desktop gradient.
bool useFlatAgeCard(double width, Brightness brightness) => false;

String movementLabel({
  required AccountSection section,
  required String type,
  String? paymentMode,
}) {
  if (section == AccountSection.libyanDeposits) {
    return type == 'payment' ? AppStrings.depositOut : AppStrings.depositIn;
  }
  if (section == AccountSection.egyptianDeposits) {
    return type == 'payment' ? AppStrings.egpOut : AppStrings.egpIn;
  }
  if (type == 'payment') {
    return switch (paymentMode) {
      'full' => AppStrings.fullPayment,
      'partial' => AppStrings.partialPayment,
      _ => AppStrings.paymentMovement,
    };
  }
  return AppStrings.debtMovement;
}

String calculationLabel(CalculationMode? mode) => switch (mode) {
  CalculationMode.divide => AppStrings.divide,
  CalculationMode.multiply => AppStrings.multiply,
  _ => AppStrings.direct,
};

String collectionStatusLabel(String status, {required bool unlinked}) {
  return switch (status) {
    'pending' => unlinked ? AppStrings.unlinked : AppStrings.pendingApproval,
    'approved' => AppStrings.approved,
    'rejected' => AppStrings.rejected,
    _ => status,
  };
}

String? reportStatusLabel(String? status) => switch (status) {
  'normal' => AppStrings.normal,
  'review' || 'needs_review' => AppStrings.review,
  'critical' || 'urgent_review' => AppStrings.critical,
  'missing_rate' || 'rate_missing' => AppStrings.missingRate,
  null || '' => null,
  _ => null,
};

(Color, Color)? reportChipColors(AppStatusColors colors, String? status) {
  return switch (status) {
    'normal' => (colors.chipNormalBg, colors.chipNormalFg),
    'review' || 'needs_review' => (colors.chipReviewBg, colors.chipReviewFg),
    'critical' ||
    'urgent_review' ||
    'missing_rate' ||
    'rate_missing' => (colors.chipCriticalBg, colors.chipCriticalFg),
    _ => null,
  };
}

/// Sign of a server integer, used only for labels the spec ties to direction.
String? vodafoneCaption(int? units) {
  if (units == null || units == 0) return null;
  return units > 0 ? AppStrings.vodafoneOurs : AppStrings.vodafoneOwed;
}

/// Visual band only. Not a financial status.
int? dayToneIndex(String day) {
  final n = int.tryParse(day.replaceAll(RegExp(r'[^0-9]'), ''));
  if (n == null) return null;
  return n % 5;
}

String dayStatusLabel(String? status) => switch (status) {
  'draft' => AppStrings.draft,
  'finalized' => AppStrings.finalized,
  'correction' || 'correctionOpen' => AppStrings.correctionOpen,
  'open' => AppStrings.draft,
  null || '' => AppStrings.dash,
  _ => status,
};

bool dayIsEditable(String? status) =>
    status == 'draft' ||
    status == 'open' ||
    status == 'correction' ||
    status == 'correctionOpen';

String notificationFallback(String action) => switch (action) {
  'collection.submit' => 'استلام جديد بانتظار المراجعة',
  'collection.approve' || 'collection.approved' => 'تم اعتماد استلام',
  'collection.reject' || 'collection.rejected' => 'تم رفض استلام',
  'collection.cash_received' => 'تم استلام النقدية',
  _ => 'إشعار',
};

Color? toneColor(AppStatusColors colors, SummaryTone? tone) => switch (tone) {
  SummaryTone.positive => colors.creditText,
  SummaryTone.negative => colors.debtText,
  _ => null,
};
