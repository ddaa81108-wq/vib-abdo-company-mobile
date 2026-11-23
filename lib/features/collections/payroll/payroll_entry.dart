import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_providers.dart';
import '../../../state/section_providers.dart';
import '../../../ui/presentation.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/mutation_form.dart';
import '../collections_strings.dart';

class PayrollEntryLine extends ConsumerWidget {
  const PayrollEntryLine({
    required this.entry,
    required this.money,
    required this.canConfirm,
    required this.manage,
    super.key,
  });
  final PayrollEntryDto entry;
  final MoneyFormatter money;
  final bool canConfirm;
  final bool manage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
    final withdrawal = entry.kind == 'withdrawal';
    final accent = withdrawal ? look.danger : look.success;
    return Container(
      key: Key('payroll-entry-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: look.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        withdrawal ? Icons.north_east : Icons.south_west,
                        size: 16,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        withdrawal
                            ? CollectionsText.withdrawal
                            : CollectionsText.commission,
                        style: cairo(12, 700, color: look.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: MoneyText(
                  money.formatOrDash(entry.amountUnits, Currency.lyd),
                  style: cairo(18, 700, color: look.ink),
                ),
              ),
            ],
          ),
          if (entry.reason != null && entry.reason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                entry.reason!,
                style: cairo(12, 500, color: look.ink),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            [?entry.createdByName, formatIsoDate(entry.createdAt)].join(' · '),
            style: cairo(10, 500, color: look.muted),
          ),
          Divider(height: 21, color: look.cardBorder),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 5,
            children: [
              if (entry.confirmedAt != null)
                Text(
                  CollectionsText.confirmed,
                  key: Key('payroll-confirmed-${entry.id}'),
                  style: cairo(11, 600, color: look.success),
                )
              else if (canConfirm)
                GuardedMutation(
                  buttonKey: Key('payroll-confirm-${entry.id}'),
                  inputs: 'confirm:${entry.id}',
                  label: CollectionsText.confirmReceipt,
                  onSubmit: (meta) async {
                    await ref
                        .read(apiLayerProvider)
                        .collections
                        .confirmPayrollEntry(entry.id, meta);
                    ref.invalidate(payrollProvider);
                    return null;
                  },
                )
              else
                Text(
                  CollectionsText.awaitingEmployee,
                  key: Key('payroll-awaiting-${entry.id}'),
                  style: cairo(10, 500, color: look.muted),
                ),
              if (manage)
                Theme(
                  data: Theme.of(context).copyWith(
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: look.danger,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        textStyle: cairo(11, 600),
                      ),
                    ),
                  ),
                  child: GuardedMutation(
                    buttonKey: Key('payroll-cancel-${entry.id}'),
                    inputs: 'cancel-payroll:${entry.id}',
                    label: CollectionsText.cancelPayrollEntry,
                    destructive: true,
                    filled: false,
                    leading: Icons.delete_outline,
                    confirmText: CollectionsText.cancelPayrollQuestion,
                    normalizedValue: money.formatOrDash(
                      entry.amountUnits,
                      Currency.lyd,
                    ),
                    onSubmit: (meta) async {
                      await ref
                          .read(apiLayerProvider)
                          .collections
                          .cancelPayrollEntry(entry.id, meta);
                      ref.invalidate(payrollProvider);
                      return null;
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
