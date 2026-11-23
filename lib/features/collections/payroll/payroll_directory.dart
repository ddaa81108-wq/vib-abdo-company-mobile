import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_providers.dart';
import '../../../ui/theme.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/common.dart';
import '../collections_strings.dart';

class PayrollDirectory extends ConsumerWidget {
  const PayrollDirectory({required this.employees, super.key});
  final List<PayrollEmployeeDto> employees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (employees.isEmpty) {
      return const EmptyPane(
        key: Key('collections-empty-payroll'),
        message: CollectionsText.noEmployees,
      );
    }
    final look = context.look, money = ref.watch(apiLayerProvider).money;
    return Column(
      key: const Key('payroll-employee-directory'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          CollectionsText.choosePayrollEmployee,
          style: cairo(12, 500, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final employee in employees)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: look.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
                side: const BorderSide(color: Color(0xFFC4A35B)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('payroll-employee-${employee.userId}'),
                onTap: () => context.push(
                  '/collections/payroll/${Uri.encodeComponent(employee.userId)}',
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, color: look.muted),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              employee.name,
                              style: cairo(16, 700, color: look.ink),
                            ),
                          ),
                          Icon(Icons.chevron_left, color: look.muted),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        CollectionsText.remaining,
                        style: cairo(11, 500, color: look.muted),
                      ),
                      MoneyText(
                        money.formatOrDash(
                          employee.remainingUnits,
                          Currency.lyd,
                        ),
                        style: context.textExtras.amount.copyWith(
                          color: (employee.remainingUnits?.asInt ?? 0) < 0
                              ? look.danger
                              : look.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        CollectionsText.openPayroll,
                        style: cairo(11, 700, color: look.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
