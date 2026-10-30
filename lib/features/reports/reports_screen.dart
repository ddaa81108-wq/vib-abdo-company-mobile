import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/export_pdf_button.dart';
import '../../ui/widgets/labeled_money.dart';

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
    final phone = width <= AppBreakpoints.phone;

    return ListView(
      key: screenKey,
      padding: pagePadding(width),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        Text(
          AppStrings.reportsReadOnly,
          style: Theme.of(context).textTheme.bodySmall,
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
              failureText(ref.read(errorHandlerProvider).toFailure(error)),
          failureOf: (error) => ref.read(errorHandlerProvider).toFailure(error),
          loading: const SkeletonBox(key: Key('reports-loading'), height: 160),
          builder: (data) {
            if (data.rows.isEmpty) {
              return const EmptyPane(
                key: Key('reports-empty'),
                message: AppStrings.emptyReports,
              );
            }
            // netChangeUnits is not displayed. ReportsDto has no current,
            // daily, or summary object yet, so the list stays the rows the
            // model already parsed. Those three shapes need api_layer.
            final current = data.rows.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CurrentDay(row: current, money: money),
                const SizedBox(height: AppSpacing.md),
                if (phone)
                  _ReportCards(rows: data.rows, money: money)
                else
                  _ReportTable(rows: data.rows, money: money),
                if (data.formula != null || data.methodologyNote != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.methodology,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (data.formula != null) Text(data.formula!),
                  if (data.methodologyNote != null) Text(data.methodologyNote!),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CurrentDay extends StatelessWidget {
  const _CurrentDay({required this.row, required this.money});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Card(
      key: const Key('report-current'),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.currentDay,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: LtrText(
                  row.date ?? AppStrings.dash,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            if (row.note != null && row.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                row.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ReportStatusChip(status: row.status),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.net,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ScaledMoney(
                money.formatOrDash(row.netUnits, Currency.lyd),
                style: context.textExtras.amountLarge.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCards extends StatelessWidget {
  const _ReportCards({required this.rows, required this.money});

  final List<DailyReportRowDto> rows;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('report-cards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final row in rows) _ReportCard(row: row, money: money)],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.row, required this.money});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('report-card-${row.sequence}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: LtrText(
                  row.date ?? AppStrings.dash,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.sequence,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                LtrText('${row.sequence}', style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ReportStatusChip(status: row.status),
            ),
            const SizedBox(height: AppSpacing.sm),
            LabeledMoney(
              label: AppStrings.net,
              value: money.formatOrDash(row.netUnits, Currency.lyd),
              valueStyle: context.textExtras.amountLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            LabeledMoney(
              label: AppStrings.ourDebts,
              value: money.formatOrDash(row.receivablesUnits, Currency.lyd),
            ),
            LabeledMoney(
              label: AppStrings.activeFunds,
              value: money.formatOrDash(row.activeCashUnits, Currency.lyd),
            ),
            LabeledMoney(
              label: AppStrings.egyptian,
              value: money.formatOrDash(row.egyptianUnits, Currency.egp),
            ),
            LabeledMoney(
              label: AppStrings.egyptianLyd,
              value: money.formatOrDash(
                row.egyptianConvertedUnits,
                Currency.lyd,
              ),
            ),
            LabeledMoney(
              label: AppStrings.owedDebts,
              value: money.formatOrDash(row.liabilitiesUnits, Currency.lyd),
            ),
            if (row.note != null && row.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(AppStrings.systemNote, style: theme.textTheme.labelLarge),
              Text(row.note!),
            ],
            if (row.reasons.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(AppStrings.reasons, style: theme.textTheme.labelLarge),
              for (final reason in row.reasons) Text(reasonLine(reason, money)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportTable extends StatefulWidget {
  const _ReportTable({required this.rows, required this.money});

  final List<DailyReportRowDto> rows;
  final MoneyFormatter money;

  @override
  State<_ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<_ReportTable> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = _columns();
    final widths = [
      for (final column in columns) _columnWidth(scale, column.glyphs),
    ];
    final headerStyle = theme.textTheme.labelMedium;
    final cellStyle = theme.textTheme.bodySmall;
    final amountStyle = context.textExtras.tableNumber.copyWith(
      color: scheme.onSurface,
    );

    Widget headerCell(_Col column) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Text(column.header, style: headerStyle),
      );
    }

    Widget textCell(String text, {bool ltr = false}) {
      final child = ltr
          ? LtrText(text, style: cellStyle)
          : Text(text, style: cellStyle);
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: child,
      );
    }

    Widget moneyCell(String value) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: ScaledMoney(
          value,
          style: amountStyle,
          alignment: Alignment.centerRight,
        ),
      );
    }

    List<Widget> cellsFor(DailyReportRowDto row) {
      final money = widget.money;
      return [
        for (final column in columns)
          switch (column.kind) {
            _ColKind.date => textCell(row.date ?? AppStrings.dash, ltr: true),
            _ColKind.sequence => textCell('${row.sequence}', ltr: true),
            _ColKind.receivables => moneyCell(
              money.formatOrDash(row.receivablesUnits, Currency.lyd),
            ),
            _ColKind.active => moneyCell(
              money.formatOrDash(row.activeCashUnits, Currency.lyd),
            ),
            _ColKind.egyptian => moneyCell(
              money.formatOrDash(row.egyptianUnits, Currency.egp),
            ),
            _ColKind.egyptianLyd => moneyCell(
              money.formatOrDash(row.egyptianConvertedUnits, Currency.lyd),
            ),
            _ColKind.liabilities => moneyCell(
              money.formatOrDash(row.liabilitiesUnits, Currency.lyd),
            ),
            _ColKind.net => moneyCell(
              money.formatOrDash(row.netUnits, Currency.lyd),
            ),
            _ColKind.status => Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: row.status == null || row.status!.isEmpty
                    ? Text(AppStrings.dash, style: cellStyle)
                    : ReportStatusChip(status: row.status),
              ),
            ),
            _ColKind.note => textCell(
              row.note == null || row.note!.isEmpty
                  ? AppStrings.dash
                  : row.note!,
            ),
            _ColKind.reasons => textCell(
              row.reasons.isEmpty
                  ? AppStrings.dash
                  : row.reasons
                        .map((reason) => reasonLine(reason, money))
                        .join('\n'),
            ),
          },
      ];
    }

    return Column(
      key: const Key('report-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.scrollColumns, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 0,
          child: SingleChildScrollView(
            key: const Key('report-table-scroll'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Table(
              columnWidths: {
                for (var i = 0; i < widths.length; i++)
                  i: FixedColumnWidth(widths[i]),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              border: TableBorder(
                horizontalInside: BorderSide(color: scheme.outlineVariant),
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
                  children: [for (final column in columns) headerCell(column)],
                ),
                for (var index = 0; index < widget.rows.length; index++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: index.isOdd
                          ? scheme.surfaceContainerLow
                          : scheme.surface,
                    ),
                    children: cellsFor(widget.rows[index]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

double _columnWidth(double scale, double glyphs) => 14 * scale * glyphs + 28;

enum _ColKind {
  date,
  sequence,
  receivables,
  active,
  egyptian,
  egyptianLyd,
  liabilities,
  net,
  status,
  note,
  reasons,
}

class _Col {
  const _Col(this.header, this.glyphs, this.kind);

  final String header;
  final double glyphs;
  final _ColKind kind;
}

List<_Col> _columns() => [
  const _Col(AppStrings.pinnedColumn, 12, _ColKind.date),
  const _Col(AppStrings.sequence, 8, _ColKind.sequence),
  const _Col(AppStrings.ourDebts, 14, _ColKind.receivables),
  const _Col(AppStrings.activeFunds, 14, _ColKind.active),
  const _Col(AppStrings.egyptian, 14, _ColKind.egyptian),
  const _Col(AppStrings.egyptianLyd, 14, _ColKind.egyptianLyd),
  const _Col(AppStrings.owedDebts, 14, _ColKind.liabilities),
  const _Col(AppStrings.net, 14, _ColKind.net),
  const _Col(AppStrings.status, 16, _ColKind.status),
  const _Col(AppStrings.systemNote, 18, _ColKind.note),
  const _Col(AppStrings.reasons, 20, _ColKind.reasons),
];

/// Reason text plus the proposed change amount. A missing amount is '—'.
String reasonLine(ReportReasonDto reason, MoneyFormatter money) {
  final text = reason.text ?? AppStrings.dash;
  return '$text ${money.formatOrDash(reason.changeUnits, Currency.lyd)}';
}
