import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/section_labels.dart';
import '../../ui/strings.dart';

/// Proposed `GET /api/home`, then the existing per-section endpoints.
///
/// A failed home call shows each section field that the server already returns.
/// Values are not added together. Cards stay neutral (no tone).
Future<HomeDto> loadHome(ApiLayer layer) async {
  try {
    return await layer.home.fetch();
  } catch (error, stack) {
    final fallback = await _fallback(layer);
    if (fallback.summaries.isEmpty) {
      Error.throwWithStackTrace(error, stack);
    }
    return fallback;
  }
}

Future<HomeDto> _fallback(ApiLayer layer) async {
  final permissions = layer.permissions;
  final cards = <HomeSummaryDto>[];
  String? businessDate;

  for (final section in AccountSection.values) {
    if (!permissions.canRead(section.sectionKey)) continue;
    try {
      final page = await layer.accounts.list(section);
      final summary = page.summary;
      final name = sectionLabel(section.sectionKey);
      cards.add(
        _card(
          key: '${section.path}.netBalance',
          section: section.path,
          title: '$name · ${AppStrings.netDebt}',
          units: summary.netBalanceUnits,
          currency: section.currency,
        ),
      );
      cards.add(
        _card(
          key: '${section.path}.totalDebt',
          section: section.path,
          title: '$name · ${AppStrings.totalDebt}',
          units: summary.totalDebtUnits,
          currency: section.currency,
        ),
      );
    } catch (_) {}
  }

  if (permissions.canRead(SectionKey.collections)) {
    try {
      final data = await layer.collections.overview();
      cards.addAll([
        _card(
          key: 'collections.collectedUnits',
          section: SectionKey.collections.key,
          title: AppStrings.collected,
          units: data.collectedUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'collections.dayTotalUnits',
          section: SectionKey.collections.key,
          title: AppStrings.dayTotal,
          units: data.dayTotalUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'collections.cashOutstandingUnits',
          section: SectionKey.collections.key,
          title: AppStrings.cashOutstanding,
          units: data.cashOutstandingUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'collections.assignedCount',
          section: SectionKey.collections.key,
          title: AppStrings.assignments,
          units: data.assignedCount,
        ),
        _card(
          key: 'collections.pendingCount',
          section: SectionKey.collections.key,
          title: AppStrings.pendingCount,
          units: data.pendingCount,
        ),
        _card(
          key: 'collections.unlinkedPendingCount',
          section: SectionKey.collections.key,
          title: AppStrings.unlinkedCount,
          units: data.unlinkedPendingCount,
        ),
      ]);
    } catch (_) {}
  }

  if (permissions.canRead(SectionKey.treasury)) {
    try {
      final data = await layer.treasury.summary();
      cards.addAll([
        _card(
          key: 'treasury.receivablesUnits',
          section: SectionKey.treasury.key,
          title: AppStrings.receivables,
          units: data.receivablesUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'treasury.liabilitiesUnits',
          section: SectionKey.treasury.key,
          title: AppStrings.liabilities,
          units: data.liabilitiesUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'treasury.activeCashUnits',
          section: SectionKey.treasury.key,
          title: AppStrings.activeCash,
          units: data.activeCashUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'treasury.egyptianSourceUnits',
          section: SectionKey.treasury.key,
          title: AppStrings.egyptianSource,
          units: data.egyptianSourceUnits,
          currency: Currency.egp,
        ),
        _card(
          key: 'treasury.egyptianConvertedUnits',
          section: SectionKey.treasury.key,
          title: AppStrings.egyptianLyd,
          units: data.egyptianConvertedUnits,
          currency: Currency.lyd,
        ),
        _card(
          key: 'treasury.netUnits',
          section: SectionKey.treasury.key,
          title: AppStrings.net,
          units: data.netUnits,
          currency: Currency.lyd,
        ),
      ]);
      final rate = data.egyptianRate?.value;
      if (rate != null) {
        cards.add(
          HomeSummaryDto(
            key: 'treasury.egyptianRate',
            section: SectionKey.treasury.key,
            title: AppStrings.rate,
            note: rate,
          ),
        );
      }
    } catch (_) {}
  }

  if (permissions.canRead(SectionKey.reports)) {
    try {
      final data = await layer.reports.daily();
      if (data.rows.isNotEmpty) {
        final row = data.rows.first;
        businessDate = row.date;
        cards.addAll([
          _card(
            key: 'reports.receivablesUnits',
            section: SectionKey.reports.key,
            title: AppStrings.receivables,
            units: row.receivablesUnits,
            currency: Currency.lyd,
            status: row.status,
          ),
          _card(
            key: 'reports.activeCashUnits',
            section: SectionKey.reports.key,
            title: AppStrings.activeCash,
            units: row.activeCashUnits,
            currency: Currency.lyd,
          ),
          _card(
            key: 'reports.liabilitiesUnits',
            section: SectionKey.reports.key,
            title: AppStrings.liabilities,
            units: row.liabilitiesUnits,
            currency: Currency.lyd,
          ),
          _card(
            key: 'reports.netUnits',
            section: SectionKey.reports.key,
            title: AppStrings.net,
            units: row.netUnits,
            currency: Currency.lyd,
          ),
        ]);
      }
    } catch (_) {}
  }

  return HomeDto(
    businessDate: businessDate,
    summaries: cards,
    counters: const {},
  );
}

HomeSummaryDto _card({
  required String key,
  required String section,
  required String title,
  required int? units,
  Currency? currency,
  String? status,
}) {
  return HomeSummaryDto(
    key: key,
    section: section,
    title: title,
    valueUnits: units,
    currency: currency,
    status: status,
  );
}
