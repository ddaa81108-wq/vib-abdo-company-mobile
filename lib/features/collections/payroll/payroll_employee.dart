import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_providers.dart';
import '../../../state/theme_controller.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/common.dart';
import '../collections_strings.dart';
import 'payroll_forms.dart';
import 'payroll_entry.dart';
import 'payroll_summary.dart';

class PayrollEmployee extends ConsumerWidget {
  const PayrollEmployee({
    required this.employee,
    required this.manage,
    super.key,
  });
  final PayrollEmployeeDto employee;
  final bool manage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final canConfirm =
        !manage &&
        !permissionsOf(ref).canDo(ManagementAction.collectionsDecide);
    final look = context.look;
    final movements = employee.movements;
    return Column(
      key: Key('payroll-${employee.userId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayrollSummary(employee: employee, money: money),
        if (manage) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final stacked =
                  box.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final buttons = [
                FilledButton.icon(
                  key: Key('payroll-add-${employee.userId}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PayrollSummary.gold,
                    foregroundColor: PayrollSummary.navy,
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  onPressed: online
                      ? () => showAppForm<void>(
                          context,
                          PayrollEntryForm(employee: employee),
                        )
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    CollectionsText.newPayrollEntry,
                    style: cairo(12, 700),
                  ),
                ),
                OutlinedButton.icon(
                  key: Key('payroll-salary-${employee.userId}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: look.ink,
                    side: BorderSide(color: look.cardBorder),
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  onPressed: online
                      ? () => showAppForm<void>(
                          context,
                          PayrollSalaryForm(employee: employee),
                        )
                      : null,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    CollectionsText.editSalary,
                    style: cairo(12, 600),
                  ),
                ),
              ];
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [buttons[0], const SizedBox(height: 8), buttons[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 10),
                  Expanded(child: buttons[1]),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.receipt_long_outlined, size: 19, color: look.muted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                CollectionsText.payrollLedger,
                style: cairo(15, 700, color: look.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (movements.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              CollectionsText.noEntries,
              textAlign: TextAlign.center,
              style: cairo(12, 500, color: look.muted),
            ),
          ),
        for (final entry in movements)
          PayrollEntryLine(
            entry: entry,
            money: money,
            canConfirm: canConfirm,
            manage: manage,
          ),
      ],
    );
  }
}
