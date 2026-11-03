import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
import 'collections_screen.dart';
import 'collections_strings.dart';

/// المرتبات (website `CollectionPayrollPanel`, 537f073). An admin sees every
/// employee, with «إضافة حركة» and the salary form; an employee sees only
/// their own card and confirms their own movements. Every figure is the
/// server's (`baseSalaryUnits` … `remainingUnits`).
class CollectionsPayrollBlock extends ConsumerWidget {
  const CollectionsPayrollBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payroll = ref.watch(payrollProvider);
    final manage = permissionsOf(ref).canDo(ManagementAction.payrollManage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionsHeading(
          // Same words as the app's other payroll headings.
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
            if (data.employees.isEmpty) {
              return const EmptyPane(
                key: Key('collections-empty-payroll'),
                message: CollectionsText.noEmployees,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final employee in data.employees)
                  _PayrollEmployee(employee: employee, manage: manage),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PayrollEmployee extends ConsumerWidget {
  const _PayrollEmployee({required this.employee, required this.manage});

  final PayrollEmployeeDto employee;
  final bool manage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final permissions = permissionsOf(ref);
    // 537f073: only the employee confirms; any admin is refused.
    final canConfirm =
        !manage && !permissions.canDo(ManagementAction.collectionsDecide);
    final look = context.look;
    String lyd(MoneyValue? units) => money.formatOrDash(units, Currency.lyd);
    final remaining = employee.remainingUnits?.asInt;
    final tiles = <(String, String, Gloss)>[
      (CollectionsText.base, lyd(employee.baseSalaryUnits), look.glossBlue),
      (
        employee.showOpeningCarry
            ? CollectionsText.carryOld
            : CollectionsText.carryPrevious,
        lyd(employee.openingCarryUnits),
        look.glossGrey,
      ),
      (
        CollectionsText.commissions,
        lyd(employee.commissionsUnits),
        look.glossViolet,
      ),
      (
        CollectionsText.withdrawals,
        lyd(employee.withdrawalsUnits),
        look.glossDebt,
      ),
      (
        CollectionsText.remaining,
        lyd(employee.remainingUnits),
        remaining != null && remaining < 0 ? look.glossDebt : look.glossCredit,
      ),
    ];
    final movements = employee.movements;
    return CollectionsPanel(
      key: Key('payroll-${employee.userId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(employee.name, style: cairo(16, 800, color: look.ink)),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow =
                  constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.3;
              const gap = AppSpacing.sm;
              final tile = narrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    SizedBox(
                      width: i == tiles.length - 1 && !narrow
                          ? constraints.maxWidth
                          : tile,
                      child: _PayrollTile(
                        label: tiles[i].$1,
                        value: tiles[i].$2,
                        gloss: tiles[i].$3,
                      ),
                    ),
                ],
              );
            },
          ),
          if (manage) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                GatedButton(
                  buttonKey: Key('payroll-add-${employee.userId}'),
                  allowed: true,
                  online: online,
                  label: CollectionsText.addEntry,
                  onPressed: () => showAppForm<void>(
                    context,
                    _PayrollEntryForm(employee: employee),
                  ),
                ),
                GatedButton(
                  buttonKey: Key('payroll-salary-${employee.userId}'),
                  allowed: true,
                  online: online,
                  filled: false,
                  label: CollectionsText.editSalary,
                  onPressed: () => showAppForm<void>(
                    context,
                    _SalaryForm(employee: employee),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '${CollectionsText.ledgerTitle}${employee.name}',
            style: cairo(13, 700, color: look.ink),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (movements.isEmpty)
            Text(
              CollectionsText.noEntries,
              style: cairo(12, 500, color: look.muted),
            ),
          for (final entry in movements)
            _PayrollEntryLine(
              entry: entry,
              money: money,
              canConfirm: canConfirm,
              admin: !canConfirm,
            ),
        ],
      ),
    );
  }
}

class _PayrollTile extends StatelessWidget {
  const _PayrollTile({
    required this.label,
    required this.value,
    required this.gloss,
  });

  final String label;
  final String value;
  final Gloss gloss;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);
    return DecoratedBox(
      decoration: gloss.decoration(radius),
      child: ClipRRect(
        borderRadius: radius,
        child: GlossSheen(
          gloss: gloss,
          radius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: cairo(11, 600, color: gloss.ink)),
                MoneyText(
                  value,
                  style: context.textExtras.amount.copyWith(
                    color: gloss.amount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayrollEntryLine extends ConsumerWidget {
  const _PayrollEntryLine({
    required this.entry,
    required this.money,
    required this.canConfirm,
    required this.admin,
  });

  final PayrollEntryDto entry;
  final MoneyFormatter money;
  final bool canConfirm;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
    final withdrawal = entry.kind == 'withdrawal';
    return Container(
      key: Key('payroll-entry-${entry.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: BorderDirectional(
          start: BorderSide(
            color: withdrawal ? look.danger : look.success,
            width: 3,
          ),
        ),
        color: (withdrawal ? look.danger : look.success).withValues(
          alpha: 0.06,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  withdrawal
                      ? CollectionsText.withdrawal
                      : CollectionsText.commission,
                  style: cairo(13, 700, color: look.ink),
                ),
              ),
              MoneyText(
                money.formatOrDash(entry.amountUnits, Currency.lyd),
                style: cairo(13, 800, color: look.ink),
              ),
            ],
          ),
          if (entry.reason != null && entry.reason!.isNotEmpty)
            Text(entry.reason!, style: cairo(12, 500, color: look.muted)),
          Text(
            [?entry.createdByName, formatIsoDate(entry.createdAt)].join(' • '),
            style: cairo(11, 500, color: look.muted),
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (entry.confirmedAt != null)
            Text(
              CollectionsText.confirmed,
              key: Key('payroll-confirmed-${entry.id}'),
              style: cairo(12, 700, color: look.success),
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
              style: cairo(12, 700, color: look.muted),
            ),
        ],
      ),
    );
  }
}

class _PayrollEntryForm extends ConsumerStatefulWidget {
  const _PayrollEntryForm({required this.employee});

  final PayrollEmployeeDto employee;

  @override
  ConsumerState<_PayrollEntryForm> createState() => _PayrollEntryFormState();
}

class _PayrollEntryFormState extends ConsumerState<_PayrollEntryForm> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  var _kind = 'withdrawal';

  @override
  void initState() {
    super.initState();
    _amount.addListener(_changed);
    _reason.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _amount.removeListener(_changed);
    _reason.removeListener(_changed);
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('payroll-entry-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${CollectionsText.addEntry} — ${widget.employee.name}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'withdrawal',
              label: Text(
                CollectionsText.addWithdrawal,
                key: Key('payroll-kind-withdrawal'),
              ),
            ),
            ButtonSegment(
              value: 'commission',
              label: Text(
                CollectionsText.addCommission,
                key: Key('payroll-kind-commission'),
              ),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (value) => setState(() => _kind = value.single),
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('payroll-amount'),
          controller: _amount,
          label: CollectionsText.amount,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('payroll-reason'),
          controller: _reason,
          maxLength: 300,
          decoration: InputDecoration(
            labelText: CollectionsText.reason,
            hintText: _kind == 'withdrawal'
                ? CollectionsText.withdrawalReason
                : CollectionsText.commissionReason,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GuardedMutation(
          buttonKey: const Key('save-payroll-entry'),
          inputs:
              'entry:${widget.employee.userId}:$_kind:${_amount.text}:${_reason.text}',
          label: CollectionsText.add,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    final reason = _reason.text.trim();
    if (units == null || units <= 0) return CollectionsText.amountRequired;
    if (reason.length < 2) return CollectionsText.reasonRequired;
    await ref
        .read(apiLayerProvider)
        .collections
        .addPayrollEntry(
          employeeUserId: widget.employee.userId,
          kind: _kind,
          amountUnits: units,
          reason: reason,
          meta: meta,
        );
    if (!mounted) return null;
    ref.invalidate(payrollProvider);
    Navigator.of(context).pop();
    return null;
  }
}

class _SalaryForm extends ConsumerStatefulWidget {
  const _SalaryForm({required this.employee});

  final PayrollEmployeeDto employee;

  @override
  ConsumerState<_SalaryForm> createState() => _SalaryFormState();
}

class _SalaryFormState extends ConsumerState<_SalaryForm> {
  late final _amount = TextEditingController(
    text: widget.employee.baseSalaryUnits?.asInt?.toString() ?? '',
  );

  @override
  void initState() {
    super.initState();
    _amount.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _amount.removeListener(_changed);
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('payroll-salary-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${CollectionsText.base} — ${widget.employee.name}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('payroll-salary-amount'),
          controller: _amount,
          label: CollectionsText.base,
        ),
        const SizedBox(height: AppSpacing.sm),
        GuardedMutation(
          buttonKey: const Key('save-salary'),
          inputs: 'salary:${widget.employee.userId}:${_amount.text}',
          label: CollectionsText.saveSalary,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    if (units == null || units < 0) return CollectionsText.salaryRequired;
    await ref
        .read(apiLayerProvider)
        .collections
        .setBaseSalary(widget.employee.userId, units, meta);
    if (!mounted) return null;
    ref.invalidate(payrollProvider);
    Navigator.of(context).pop();
    return null;
  }
}
