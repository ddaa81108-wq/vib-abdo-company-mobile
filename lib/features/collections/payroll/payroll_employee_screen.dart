import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../error_handling/error_handler.dart';
import '../../../state/section_gate.dart';
import '../../../state/section_providers.dart';
import '../../../state/session_providers.dart';
import '../../../state/theme_controller.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/common.dart';
import '../collections_strings.dart';
import 'payroll_employee.dart';

class PayrollEmployeeScreen extends ConsumerWidget {
  const PayrollEmployeeScreen({required this.employeeId, super.key});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final manage = permissions.canDo(ManagementAction.payrollManage);
    final session = ref.watch(sessionStateProvider);
    final own =
        session is SessionAuthenticated && session.profile.id == employeeId;
    final held = sectionGate(
      ref,
      allowed: permissions.canRead(SectionKey.collections) && (manage || own),
    );
    if (held != null) return held;
    final payroll = ref.watch(payrollProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(payrollProvider);
        await ref.read(payrollProvider.future);
      },
      child: ListView(
        key: Key('payroll-page-$employeeId'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('payroll-employees-back'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(CollectionsText.backToEmployees),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/collections?view=payroll');
                }
              },
            ),
          ),
          if (payroll.value?.period != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                '${CollectionsText.currentPeriod}${payroll.value!.period}',
              ),
            ),
          payroll.when(
            loading: () =>
                const SkeletonBox(key: Key('payroll-loading'), height: 160),
            error: (error, _) => presentFailure(
              ref.read(errorHandlerProvider).toFailure(error),
              onRetry: () => ref.invalidate(payrollProvider),
              retryKey: const Key('payroll-retry'),
            ),
            data: (data) {
              final employee = data.employees
                  .where((row) => row.userId == employeeId)
                  .firstOrNull;
              if (employee == null) {
                return const EmptyPane(
                  message: CollectionsText.payrollNotAvailable,
                );
              }
              return PayrollEmployee(employee: employee, manage: manage);
            },
          ),
        ],
      ),
    );
  }
}
