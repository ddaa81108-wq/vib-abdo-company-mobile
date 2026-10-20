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
import 'unlinked_receipt_actions.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  static const screenKey = Key('screen-collections');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.collections)) {
      return const ForbiddenPane();
    }
    final overview = ref.watch(collectionsProvider);
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final manage = permissions.canDo(ManagementAction.collectionsDecide);
    final cash = permissions.canDo(ManagementAction.collectionsCashReceived);
    final close = permissions.canDo(ManagementAction.collectionsCloseDay);
    final payroll = permissions.canDo(ManagementAction.payrollManage);
    final write = permissions.canWrite(SectionKey.collections);

    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle('استلامات الديون'),
        const SizedBox(height: AppSpacing.md),
        KeptData<CollectionsOverviewDto>(
          value: overview,
          resetKey: 'collections',
          onRetry: () => ref.invalidate(collectionsProvider),
          messageOf: (error) =>
              ref.read(errorHandlerProvider).toFailure(error).message,
          loading: const SkeletonBox(key: Key('collections-loading')),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (manage) _Metrics(data: data, money: money),
              if (manage && data.employeeTotals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.employeeTotals,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final row in data.employeeTotals)
                  ListTile(
                    title: Text(row.employeeName),
                    subtitle: Text(
                      '${money.formatOrDash(row.collectedUnits, Currency.lyd)} · ${row.pendingCount ?? AppStrings.dash}',
                    ),
                  ),
              ],
              if (write) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.assignments,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final assignment in data.assignments)
                  _Assignment(
                    assignment: assignment,
                    money: money,
                    online: online,
                  ),
                GatedButton(
                  buttonKey: const Key('unlinked-collection'),
                  allowed: true,
                  online: online,
                  label: AppStrings.unlinkedReceipt,
                  onPressed: () => _unlinked(context, ref),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final submission in data.submissions)
                _Submission(
                  submission: submission,
                  money: money,
                  manage: manage,
                  cash: cash,
                  online: online,
                ),
              for (final receipt in data.unlinkedReceipts)
                _Unlinked(
                  receipt: receipt,
                  money: money,
                  manage: manage,
                  online: online,
                ),
              if (close && data.batchId != null)
                GuardedMutation(
                  buttonKey: const Key('close-batch'),
                  inputs: 'close:${data.batchId}',
                  label: AppStrings.closeBatch,
                  confirmText: AppStrings.closeBatchConfirm,
                  destructive: true,
                  onSubmit: (meta) => _close(context, ref, data.batchId!, meta),
                ),
              if (write || payroll) const _PayrollBlock(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _unlinked(BuildContext context, WidgetRef ref) {
    return showAppForm<void>(context, const _UnlinkedForm());
  }

  Future<String?> _close(
    BuildContext context,
    WidgetRef ref,
    String batchId,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .closeDay(batchId: batchId, meta: meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(collectionsProvider);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _UnlinkedForm extends ConsumerStatefulWidget {
  const _UnlinkedForm();

  @override
  ConsumerState<_UnlinkedForm> createState() => _UnlinkedFormState();
}

class _UnlinkedFormState extends ConsumerState<_UnlinkedForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _amount.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_changed);
    _amount.removeListener(_changed);
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('unlinked-name'),
          controller: _name,
          decoration: const InputDecoration(labelText: AppStrings.customerName),
        ),
        UnitsField(
          key: const Key('unlinked-amount'),
          controller: _amount,
          label: AppStrings.amount,
        ),
        GuardedMutation(
          buttonKey: const Key('save-unlinked'),
          inputs: '${_name.text}|${_amount.text}',
          label: AppStrings.save,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    if (units == null || _name.text.trim().isEmpty) {
      return AppStrings.integerOnly;
    }
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .createUnlinkedReceipt(
            customerName: _name.text.trim(),
            amountUnits: units,
            meta: meta,
          );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(collectionsProvider);
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data, required this.money});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        AppStrings.collected,
        money.formatOrDash(data.collectedUnits, Currency.lyd),
      ),
      (
        AppStrings.assignments,
        data.assignedCount == null ? AppStrings.dash : '${data.assignedCount}',
      ),
      (
        AppStrings.dayTotal,
        money.formatOrDash(data.dayTotalUnits, Currency.lyd),
      ),
      (
        AppStrings.pendingCount,
        data.pendingCount == null ? AppStrings.dash : '${data.pendingCount}',
      ),
      (
        AppStrings.unlinkedCount,
        data.unlinkedPendingCount == null
            ? AppStrings.dash
            : '${data.unlinkedPendingCount}',
      ),
      (
        AppStrings.cashOutstanding,
        money.formatOrDash(data.cashOutstandingUnits, Currency.lyd),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tile in tiles)
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.$1, style: Theme.of(context).textTheme.bodySmall),
                  Text(tile.$2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Assignment extends ConsumerWidget {
  const _Assignment({
    required this.assignment,
    required this.money,
    required this.online,
  });

  final CollectionAssignmentDto assignment;
  final MoneyFormatter money;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(assignment.customerName),
            subtitle: Text(
              money.formatOrDash(assignment.balanceUnits, Currency.lyd),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GatedButton(
              buttonKey: Key('submit-${assignment.id}'),
              allowed: true,
              online: online,
              label: AppStrings.submitReceipt,
              onPressed: () => showAppForm<void>(
                context,
                _AssignmentForm(assignmentId: assignment.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentForm extends ConsumerStatefulWidget {
  const _AssignmentForm({required this.assignmentId});

  final String assignmentId;

  @override
  ConsumerState<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends ConsumerState<_AssignmentForm> {
  final _amount = TextEditingController();
  var _full = false;

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text(AppStrings.modeFull),
          value: _full,
          onChanged: (value) => setState(() => _full = value),
        ),
        if (!_full) UnitsField(controller: _amount, label: AppStrings.amount),
        GuardedMutation(
          buttonKey: const Key('save-assignment'),
          inputs: '$_full|${_amount.text}',
          label: AppStrings.save,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = _full ? null : parseUnits(_amount.text);
    if (!_full && units == null) return AppStrings.integerOnly;
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .submit(
            widget.assignmentId,
            mode: _full ? 'full' : 'partial',
            amountUnits: units,
            meta: meta,
          );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(collectionsProvider);
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _Submission extends ConsumerWidget {
  const _Submission({
    required this.submission,
    required this.money,
    required this.manage,
    required this.cash,
    required this.online,
  });

  final CollectionSubmissionDto submission;
  final MoneyFormatter money;
  final bool manage;
  final bool cash;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = submission.cashStatus == CashStatus.pending;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(submission.submittedByName ?? AppStrings.dash),
            MoneyText(money.formatOrDash(submission.amountUnits, Currency.lyd)),
            Text(
              submission.mode == 'full'
                  ? AppStrings.modeFull
                  : AppStrings.modePartial,
            ),
            Text(collectionStatusLabel(submission.status, unlinked: false)),
            if (awaiting)
              Text(
                AppStrings.awaitingCash,
                key: const Key('awaiting-cash'),
                style: cairo(
                  12,
                  800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (manage && submission.status == 'pending')
              Wrap(
                children: [
                  GuardedMutation(
                    buttonKey: Key('approve-${submission.id}'),
                    inputs: 'approve:${submission.id}:${submission.version}',
                    expectedVersion: submission.version,
                    label: AppStrings.approve,
                    onSubmit: (meta) =>
                        _decide(context, ref, CollectionDecision.approve, meta),
                  ),
                  GuardedMutation(
                    buttonKey: Key('reject-${submission.id}'),
                    inputs: 'reject:${submission.id}:${submission.version}',
                    expectedVersion: submission.version,
                    label: AppStrings.reject,
                    filled: false,
                    onSubmit: (meta) =>
                        _decide(context, ref, CollectionDecision.reject, meta),
                  ),
                ],
              ),
            if (cash && awaiting)
              GuardedMutation(
                buttonKey: Key('cash-${submission.id}'),
                inputs: 'cash:${submission.id}:${submission.version}',
                expectedVersion: submission.version,
                label: AppStrings.cashReceived,
                onSubmit: (meta) => _cash(context, ref, meta),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _decide(
    BuildContext context,
    WidgetRef ref,
    CollectionDecision decision,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .decide(submission.id, decision, meta: meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(collectionsProvider);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }

  Future<String?> _cash(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .markCashReceived(submission.id, meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(collectionsProvider);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _Unlinked extends ConsumerWidget {
  const _Unlinked({
    required this.receipt,
    required this.money,
    required this.manage,
    required this.online,
  });

  final UnlinkedReceiptDto receipt;
  final MoneyFormatter money;
  final bool manage;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = receipt.cashStatus == CashStatus.pending;
    return Card(
      color: receipt.status == 'approved'
          ? context.statusColors.unlinkedApproved
          : context.statusColors.unlinkedPending,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              receipt.customerName,
              style: cairo(14, 700, color: context.statusColors.onStatus),
            ),
            Text(
              '${money.formatOrDash(receipt.amountUnits, Currency.lyd)} · ${collectionStatusLabel(receipt.status, unlinked: true)}',
              style: cairo(12, 500, color: context.statusColors.onStatus),
            ),
            if (awaiting)
              Text(
                AppStrings.awaitingCash,
                key: Key('awaiting-cash-${receipt.id}'),
                style: cairo(12, 800, color: context.statusColors.onStatus),
              ),
            if (manage && receipt.status == 'pending')
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  GuardedMutation(
                    buttonKey: Key('unlinked-approve-${receipt.id}'),
                    inputs: 'ulink:${receipt.id}:${receipt.version}',
                    expectedVersion: receipt.version,
                    label: AppStrings.approve,
                    onSubmit: (meta) =>
                        _decide(context, ref, CollectionDecision.approve, meta),
                  ),
                  GatedButton(
                    buttonKey: Key('unlinked-link-${receipt.id}'),
                    allowed: true,
                    online: online,
                    filled: false,
                    label: AppStrings.link,
                    onPressed: () =>
                        showAppForm<void>(context, _LinkForm(receipt: receipt)),
                  ),
                ],
              ),
            UnlinkedReceiptActions(receipt: receipt),
          ],
        ),
      ),
    );
  }

  Future<String?> _decide(
    BuildContext context,
    WidgetRef ref,
    CollectionDecision decision,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .decideUnlinked(receipt.id, decision: decision, meta: meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(collectionsProvider);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _LinkForm extends ConsumerStatefulWidget {
  const _LinkForm({required this.receipt});

  final UnlinkedReceiptDto receipt;

  @override
  ConsumerState<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends ConsumerState<_LinkForm> {
  final _customer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('link-customer'),
          controller: _customer,
          decoration: const InputDecoration(labelText: AppStrings.reference),
        ),
        GuardedMutation(
          buttonKey: const Key('save-link'),
          inputs: 'link:${widget.receipt.id}:${_customer.text}',
          expectedVersion: widget.receipt.version,
          label: AppStrings.link,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final customerId = _customer.text.trim();
    if (customerId.isEmpty) return AppStrings.enterReference;
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .decideUnlinked(
            widget.receipt.id,
            decision: CollectionDecision.approve,
            customerId: customerId,
            meta: meta,
          );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(collectionsProvider);
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _PayrollBlock extends ConsumerWidget {
  const _PayrollBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payroll = ref.watch(payrollProvider);
    final money = ref.watch(apiLayerProvider).money;
    final permissions = permissionsOf(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          permissions.canDo(ManagementAction.payrollManage)
              ? AppStrings.payroll
              : AppStrings.myPayroll,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        payroll.when(
          loading: () => const SkeletonBox(height: 64),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(payrollProvider),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.period != null)
                Text('${AppStrings.period} ${data.period}'),
              for (final employee in data.employees)
                ListTile(
                  title: Text(employee.name),
                  subtitle: Text(
                    '${AppStrings.remaining} ${money.formatOrDash(employee.remainingUnits, Currency.lyd)}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
