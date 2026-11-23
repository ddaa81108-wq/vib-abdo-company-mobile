import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_providers.dart';
import '../../../state/section_providers.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/mutation_form.dart';
import '../collections_strings.dart';

class PayrollEntryForm extends ConsumerStatefulWidget {
  const PayrollEntryForm({required this.employee, super.key});

  final PayrollEmployeeDto employee;

  @override
  ConsumerState<PayrollEntryForm> createState() => PayrollEntryFormState();
}

class PayrollEntryFormState extends ConsumerState<PayrollEntryForm> {
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

class PayrollSalaryForm extends ConsumerStatefulWidget {
  const PayrollSalaryForm({required this.employee, super.key});

  final PayrollEmployeeDto employee;

  @override
  ConsumerState<PayrollSalaryForm> createState() => PayrollSalaryFormState();
}

class PayrollSalaryFormState extends ConsumerState<PayrollSalaryForm> {
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
