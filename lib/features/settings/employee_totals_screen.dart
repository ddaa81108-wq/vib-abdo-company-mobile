import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/employee_totals_provider.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

/// Admin dashboard for [employeeTotalsStateProvider].
///
/// Money and counts are shown as the server sent them. This screen does not
/// add rows, fill a null total with zero, or copy one field onto another.
class EmployeeTotalsScreen extends ConsumerWidget {
  const EmployeeTotalsScreen({super.key});

  static const screenKey = Key('screen-employee-totals');
  static const loadingKey = Key('employee-totals-loading');
  static const retryKey = Key('employee-totals-retry');
  static const cardsKey = Key('employee-totals-cards');
  static const tableKey = Key('employee-totals-table');
  static const summaryKey = Key('employee-totals-summary');

  static Key rowKey(String id) => Key('employee-total-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = permissionsOf(ref).canViewEmployeeTotals;
    final state = ref.watch(employeeTotalsStateProvider);
    final Widget body;
    if (!allowed || state is EmployeeTotalsForbidden) {
      body = const ForbiddenPane();
    } else {
      body = switch (state) {
        EmployeeTotalsLoading() => const _Loading(),
        EmployeeTotalsFailure(:final error) => _Failure(error: error),
        EmployeeTotalsReady(:final report) => _Ready(report: report),
        EmployeeTotalsForbidden() => const ForbiddenPane(),
      };
    }
    return KeyedSubtree(key: screenKey, child: body);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: EmployeeTotalsScreen.loadingKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: const [
        ScreenTitle(AppStrings.employeeTotals),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 88),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 160),
      ],
    );
  }
}

class _Failure extends ConsumerWidget {
  const _Failure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.read(errorHandlerProvider).toFailure(error).message;
    return ListView(
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.employeeTotals),
        const SizedBox(height: AppSpacing.md),
        ErrorPane(
          message: message,
          onRetry: () => ref.invalidate(employeeTotalsProvider),
          retryKey: EmployeeTotalsScreen.retryKey,
        ),
      ],
    );
  }
}

class _Ready extends ConsumerWidget {
  const _Ready({required this.report});

  final EmployeeTotalsDto report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(apiLayerProvider).money;
    final tight = layoutIsTight(context);
    return ListView(
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.employeeTotals),
        const SizedBox(height: AppSpacing.md),
        if (tight)
          _Cards(report: report, money: money)
        else
          _Table(report: report, money: money),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.report, required this.money});

  final EmployeeTotalsDto report;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: EmployeeTotalsScreen.cardsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < report.items.length; i++)
          _EmployeeCard(item: report.items[i], index: i, money: money),
        _SummaryCard(report: report, money: money),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.item,
    required this.index,
    required this.money,
  });

  final EmployeeTotalsItemDto item;
  final int index;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final id = item.employeeId ?? 'row-$index';
    return Card(
      key: EmployeeTotalsScreen.rowKey(id),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.employeeName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._itemLines(context, item, money, id),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report, required this.money});

  final EmployeeTotalsDto report;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: EmployeeTotalsScreen.summaryKey,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.serverTotals,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._summaryLines(context, report, money),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.report, required this.money});

  final EmployeeTotalsDto report;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = _columns;
    return Column(
      key: EmployeeTotalsScreen.tableKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.scrollColumns, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          key: const Key('employee-totals-table-scroll'),
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: {
              for (var i = 0; i < columns.length; i++)
                i: FixedColumnWidth(14 * scale * columns[i].glyphs + 28),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            border: TableBorder(
              horizontalInside: BorderSide(color: scheme.outlineVariant),
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
                children: [
                  for (final column in columns) _header(context, column.label),
                ],
              ),
              for (var i = 0; i < report.items.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isOdd
                        ? scheme.surfaceContainerLow
                        : scheme.surface,
                  ),
                  children: _itemCells(context, report.items[i], i, money),
                ),
              TableRow(
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
                children: _summaryCells(context, report, money),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Column {
  const _Column(this.label, this.glyphs);

  final String label;
  final double glyphs;
}

const _columns = <_Column>[
  _Column(AppStrings.assignee, 16),
  _Column(AppStrings.collected, 14),
  _Column(AppStrings.pendingUnits, 14),
  _Column(AppStrings.cashOutstanding, 16),
  _Column(AppStrings.approvedCount, 12),
  _Column(AppStrings.rejectedCount, 12),
  _Column(AppStrings.pendingCount, 12),
];

List<Widget> _itemLines(
  BuildContext context,
  EmployeeTotalsItemDto item,
  MoneyFormatter money,
  String id,
) {
  return [
    _moneyLine(
      context,
      AppStrings.collected,
      money.formatOrDash(item.collectedUnits, item.currency),
      _collectedColor(context),
      Key('money-collected-$id'),
    ),
    _moneyLine(
      context,
      AppStrings.pendingUnits,
      money.formatOrDash(item.pendingUnits, item.currency),
      null,
      Key('money-pending-$id'),
    ),
    _moneyLine(
      context,
      AppStrings.cashOutstanding,
      money.formatOrDash(item.cashOutstandingUnits, item.currency),
      _outstandingColor(context),
      Key('money-cash-$id'),
    ),
    _countLine(context, AppStrings.approvedCount, item.approvedCount),
    _countLine(context, AppStrings.rejectedCount, item.rejectedCount),
    _countLine(context, AppStrings.pendingCount, item.pendingCount),
  ];
}

List<Widget> _summaryLines(
  BuildContext context,
  EmployeeTotalsDto report,
  MoneyFormatter money,
) {
  final currency = report.currency;
  return [
    _moneyLine(
      context,
      AppStrings.collected,
      money.formatOrDash(report.totals.collectedUnits, currency),
      _collectedColor(context),
      const Key('money-collected-totals'),
    ),
    _moneyLine(
      context,
      AppStrings.pendingUnits,
      money.formatOrDash(report.totals.pendingUnits, currency),
      null,
      const Key('money-pending-totals'),
    ),
  ];
}

List<Widget> _itemCells(
  BuildContext context,
  EmployeeTotalsItemDto item,
  int index,
  MoneyFormatter money,
) {
  final id = item.employeeId ?? 'row-$index';
  return [
    _textCell(context, item.employeeName, key: EmployeeTotalsScreen.rowKey(id)),
    _moneyCell(
      context,
      money.formatOrDash(item.collectedUnits, item.currency),
      _collectedColor(context),
      Key('money-collected-$id'),
    ),
    _moneyCell(
      context,
      money.formatOrDash(item.pendingUnits, item.currency),
      null,
      Key('money-pending-$id'),
    ),
    _moneyCell(
      context,
      money.formatOrDash(item.cashOutstandingUnits, item.currency),
      _outstandingColor(context),
      Key('money-cash-$id'),
    ),
    _textCell(context, _count(item.approvedCount)),
    _textCell(context, _count(item.rejectedCount)),
    _textCell(context, _count(item.pendingCount)),
  ];
}

List<Widget> _summaryCells(
  BuildContext context,
  EmployeeTotalsDto report,
  MoneyFormatter money,
) {
  final currency = report.currency;
  return [
    _textCell(
      context,
      AppStrings.serverTotals,
      key: EmployeeTotalsScreen.summaryKey,
    ),
    _moneyCell(
      context,
      money.formatOrDash(report.totals.collectedUnits, currency),
      _collectedColor(context),
      const Key('money-collected-totals'),
    ),
    _moneyCell(
      context,
      money.formatOrDash(report.totals.pendingUnits, currency),
      null,
      const Key('money-pending-totals'),
    ),
    _textCell(context, AppStrings.dash),
    _textCell(context, AppStrings.dash),
    _textCell(context, AppStrings.dash),
    _textCell(context, AppStrings.dash),
  ];
}

Widget _moneyLine(
  BuildContext context,
  String label,
  String value,
  Color? color,
  Key key,
) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        MoneyText(value, key: key, style: _amountStyle(context, color)),
      ],
    ),
  );
}

Widget _countLine(BuildContext context, String label, int? value) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(_count(value), style: context.textExtras.amount),
      ],
    ),
  );
}

Widget _header(BuildContext context, String label) {
  return Padding(
    padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );
}

Widget _textCell(BuildContext context, String text, {Key? key}) {
  return Padding(
    key: key,
    padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

Widget _moneyCell(BuildContext context, String value, Color? color, Key key) {
  return Padding(
    padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
    child: MoneyText(value, key: key, style: _amountStyle(context, color)),
  );
}

TextStyle? _amountStyle(BuildContext context, Color? color) {
  final amount = context.textExtras.amount;
  if (color == null) return amount;
  return amount.copyWith(color: color);
}

/// Collected money uses the same colour as a payment (credit).
Color _collectedColor(BuildContext context) => context.statusColors.creditText;

/// Cash still outstanding uses the same colour as a debt.
Color _outstandingColor(BuildContext context) => context.statusColors.debtText;

String _count(int? value) => value == null ? AppStrings.dash : '$value';
