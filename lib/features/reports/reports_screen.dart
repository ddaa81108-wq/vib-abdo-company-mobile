import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/export_pdf_button.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  static const screenKey = Key('screen-reports');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.reports)) return const ForbiddenPane();
    final reports = ref.watch(reportsProvider);
    final money = ref.watch(apiLayerProvider).money;
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      key: screenKey,
      padding: pagePadding(width),
      children: [
        Row(
          children: [
            const Expanded(child: ScreenTitle(AppStrings.reports)),
            IconButton(
              key: const Key('reports-refresh'),
              tooltip: AppStrings.refresh,
              onPressed: () => ref.invalidate(reportsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExportPdfButton(),
        ),
        KeptData<ReportsDto>(
          value: reports,
          resetKey: 'reports',
          onRetry: () => ref.invalidate(reportsProvider),
          messageOf: (error) =>
              ref.read(errorHandlerProvider).toFailure(error).message,
          loading: const SkeletonBox(key: Key('reports-loading'), height: 160),
          builder: (data) {
            if (data.rows.isEmpty) {
              return const EmptyPane(message: AppStrings.emptyReports);
            }
            final showChange = data.rows.any(
              (row) => row.netChangeUnits != null,
            );
            final current = data.rows.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(current.date ?? AppStrings.dash),
                        if (current.note != null && current.note!.isNotEmpty)
                          Text(current.note!),
                        ReportStatusChip(status: current.status),
                        MoneyText(
                          money.formatOrDash(current.netUnits, Currency.lyd),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (width <= AppBreakpoints.phone)
                  for (final row in data.rows)
                    _ReportCard(row: row, money: money, showChange: showChange)
                else
                  _Table(rows: data.rows, money: money, showChange: showChange),
                if (data.formula != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.methodology,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(data.formula!),
                ],
                if (data.methodologyNote != null) Text(data.methodologyNote!),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.row,
    required this.money,
    required this.showChange,
  });

  final DailyReportRowDto row;
  final MoneyFormatter money;
  final bool showChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        title: Text(row.date ?? AppStrings.dash),
        subtitle: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MoneyText(money.formatOrDash(row.netUnits, Currency.lyd)),
            ReportStatusChip(status: row.status),
          ],
        ),
        children: [_facts(context)],
      ),
    );
  }

  Widget _facts(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppStrings.ourDebts} ${money.formatOrDash(row.receivablesUnits, Currency.lyd)}',
          ),
          Text(
            '${AppStrings.activeFunds} ${money.formatOrDash(row.activeCashUnits, Currency.lyd)}',
          ),
          Text(
            '${AppStrings.egyptian} ${money.formatOrDash(row.egyptianUnits, Currency.egp)}',
          ),
          Text(
            '${AppStrings.egyptianLyd} ${money.formatOrDash(row.egyptianConvertedUnits, Currency.lyd)}',
          ),
          Text(
            '${AppStrings.owedDebts} ${money.formatOrDash(row.liabilitiesUnits, Currency.lyd)}',
          ),
          if (showChange)
            Text(
              '${AppStrings.netChange} ${money.formatOrDash(row.netChangeUnits, Currency.lyd)}',
            ),
          if (row.note != null) Text(row.note!),
          for (final reason in row.reasons)
            Text('${AppStrings.reasons}: ${reasonLine(reason, money)}'),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.rows,
    required this.money,
    required this.showChange,
  });

  final List<DailyReportRowDto> rows;
  final MoneyFormatter money;
  final bool showChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 36, child: Text(AppStrings.pinnedColumn)),
            for (final row in rows)
              SizedBox(height: 36, child: Text(row.date ?? AppStrings.dash)),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      const Text(AppStrings.sequence),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.ourDebts),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.activeFunds),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.egyptian),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.egyptianLyd),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.owedDebts),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.net),
                      if (showChange) ...[
                        const SizedBox(width: AppSpacing.md),
                        const Text(AppStrings.netChange),
                      ],
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.status),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.systemNote),
                      const SizedBox(width: AppSpacing.md),
                      const Text(AppStrings.reasons),
                    ],
                  ),
                ),
                for (final row in rows)
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        Text('${row.sequence}'),
                        const SizedBox(width: AppSpacing.md),
                        MoneyText(
                          money.formatOrDash(
                            row.receivablesUnits,
                            Currency.lyd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MoneyText(
                          money.formatOrDash(row.activeCashUnits, Currency.lyd),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MoneyText(
                          money.formatOrDash(row.egyptianUnits, Currency.egp),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MoneyText(
                          money.formatOrDash(
                            row.egyptianConvertedUnits,
                            Currency.lyd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MoneyText(
                          money.formatOrDash(
                            row.liabilitiesUnits,
                            Currency.lyd,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MoneyText(
                          money.formatOrDash(row.netUnits, Currency.lyd),
                        ),
                        if (showChange) ...[
                          const SizedBox(width: AppSpacing.md),
                          MoneyText(
                            money.formatOrDash(
                              row.netChangeUnits,
                              Currency.lyd,
                            ),
                          ),
                        ],
                        const SizedBox(width: AppSpacing.md),
                        ReportStatusChip(status: row.status),
                        const SizedBox(width: AppSpacing.md),
                        Text(row.note ?? AppStrings.dash),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          row.reasons.isEmpty
                              ? AppStrings.dash
                              : row.reasons
                                    .map((reason) => reasonLine(reason, money))
                                    .join(' · '),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reason text plus the proposed change amount. A missing amount is '—'.
String reasonLine(ReportReasonDto reason, MoneyFormatter money) {
  final text = reason.text ?? AppStrings.dash;
  return '$text ${money.formatOrDash(reason.changeUnits, Currency.lyd)}';
}
