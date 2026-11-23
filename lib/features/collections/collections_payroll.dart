import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/common.dart';
import 'collections_screen.dart';
import 'collections_strings.dart';
import 'payroll/payroll_directory.dart';
import 'payroll/payroll_employee.dart';

/// Administration opens one employee at a time. Figures remain server-owned.
class CollectionsPayrollBlock extends ConsumerWidget {
  const CollectionsPayrollBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payroll = ref.watch(payrollProvider);
    final manage = permissionsOf(ref).canDo(ManagementAction.payrollManage);
    final session = ref.watch(sessionStateProvider);
    final userId = session is SessionAuthenticated ? session.profile.id : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionsHeading(
          manage ? AppStrings.payroll : AppStrings.myPayroll,
          note: payroll.value?.period == null
              ? null
              : '${CollectionsText.currentPeriod}${payroll.value!.period}',
        ),
        payroll.when(
          loading: () =>
              const SkeletonBox(key: Key('payroll-loading'), height: 88),
          error: (error, _) => presentFailure(
            ref.read(errorHandlerProvider).toFailure(error),
            onRetry: () => ref.invalidate(payrollProvider),
            retryKey: const Key('payroll-retry'),
          ),
          data: (data) {
            if (manage) {
              return PayrollDirectory(employees: data.employees);
            }
            final employee = data.employees
                .where((row) => row.userId == userId)
                .firstOrNull;
            if (employee == null) {
              return const EmptyPane(
                key: Key('collections-empty-payroll'),
                message: CollectionsText.noEmployees,
              );
            }
            return PayrollEmployee(employee: employee, manage: false);
          },
        ),
      ],
    );
  }
}
