import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/section_labels.dart';
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
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      key: screenKey,
      padding: pagePadding(width).copyWith(bottom: AppSpacing.xxl),
      children: [
        ScreenTitle(sectionLabel(SectionKey.collections)),
        const SizedBox(height: AppSpacing.md),
        KeptData<CollectionsOverviewDto>(
          value: overview,
          resetKey: 'collections',
          onRetry: () => ref.invalidate(collectionsProvider),
          messageOf: (error) =>
              ref.read(errorHandlerProvider).toFailure(error).message,
          loading: const _CollectionsLoading(),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (manage)
                _Metrics(
                  key: const Key('collections-metrics'),
                  data: data,
                  money: money,
                ),
              if (manage) ...[
                const _SectionHeading(AppStrings.employeeTotals),
                if (data.employeeTotals.isEmpty)
                  const EmptyPane(
                    key: Key('collections-empty-totals'),
                    message: AppStrings.emptyEmployeeTotals,
                  )
                else
                  for (final row in data.employeeTotals)
                    _EmployeeTotal(row: row, money: money),
              ],
              if (write) ...[
                const _SectionHeading(AppStrings.assignments),
                if (data.assignments.isEmpty)
                  const EmptyPane(
                    key: Key('collections-empty-assignments'),
                    message: AppStrings.emptyAssignments,
                  )
                else
                  for (final assignment in data.assignments)
                    _Assignment(
                      assignment: assignment,
                      money: money,
                      online: online,
                    ),
                const SizedBox(height: AppSpacing.sm),
                GatedButton(
                  buttonKey: const Key('unlinked-collection'),
                  allowed: true,
                  online: online,
                  label: AppStrings.unlinkedReceipt,
                  onPressed: () => _unlinked(context, ref),
                ),
              ],
              const _SectionHeading(AppStrings.receipts),
              if (data.submissions.isEmpty && data.unlinkedReceipts.isEmpty)
                const EmptyPane(
                  key: Key('collections-empty-receipts'),
                  message: AppStrings.emptyCollections,
                ),
              for (final submission in data.submissions)
                _Submission(
                  submission: submission,
                  money: money,
                  manage: manage,
                  cash: cash,
                ),
              for (final receipt in data.unlinkedReceipts)
                _Unlinked(
                  receipt: receipt,
                  money: money,
                  manage: manage,
                  cash: cash,
                  online: online,
                ),
              if (close && data.batchId != null) ...[
                const SizedBox(height: AppSpacing.md),
                _IdLine(label: AppStrings.batch, value: data.batchId!),
                GuardedMutation(
                  buttonKey: const Key('close-batch'),
                  inputs: 'close:${data.batchId}',
                  label: AppStrings.closeBatch,
                  confirmText: AppStrings.closeBatchConfirm,
                  destructive: true,
                  onSubmit: (meta) => _close(context, ref, data.batchId!, meta),
                ),
              ],
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

class _CollectionsLoading extends StatelessWidget {
  const _CollectionsLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('collections-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 72),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 120),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 120),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data, required this.money, super.key});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String, bool)>[
      (
        AppStrings.collected,
        money.formatOrDash(data.collectedUnits, Currency.lyd),
        true,
      ),
      (AppStrings.assignments, _count(data.assignedCount), false),
      (
        AppStrings.dayTotal,
        money.formatOrDash(data.dayTotalUnits, Currency.lyd),
        true,
      ),
      (AppStrings.pendingCount, _count(data.pendingCount), false),
      (AppStrings.unlinkedCount, _count(data.unlinkedPendingCount), false),
      (
        AppStrings.cashOutstanding,
        money.formatOrDash(data.cashOutstandingUnits, Currency.lyd),
        true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _tight(context, width) ? 1 : 2;
        final gap = AppSpacing.sm;
        final tileWidth = columns == 1 ? width : (width - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: _MetricTile(
                  label: tile.$1,
                  value: tile.$2,
                  money: tile.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.money,
  });

  final String label;
  final String value;
  final bool money;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            _Figure(value: value, money: money),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTotal extends StatelessWidget {
  const _EmployeeTotal({required this.row, required this.money});

  final EmployeeTotalDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.employeeName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _AmountLine(
              label: AppStrings.collected,
              value: money.formatOrDash(row.collectedUnits, Currency.lyd),
            ),
            _AmountLine(
              label: AppStrings.approved,
              value: _count(row.approvedCount),
              money: false,
            ),
            _AmountLine(
              label: AppStrings.pendingCount,
              value: _count(row.pendingCount),
              money: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _Assignment extends StatelessWidget {
  const _Assignment({
    required this.assignment,
    required this.money,
    required this.online,
  });

  final CollectionAssignmentDto assignment;
  final MoneyFormatter money;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final section = _knownSection(assignment.section);
    final open = assignment.status == 'open';
    return Card(
      key: Key('assignment-${assignment.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignment.customerName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (section != null)
              Text(
                sectionLabel(section),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (assignment.phone != null)
              LtrText(
                assignment.phone!,
                style: context.textExtras.tableNumber.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            if (assignment.assigneeName != null)
              Text(
                '${AppStrings.withEmployee} ${assignment.assigneeName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (open)
              Text(
                AppStrings.assignmentOpen,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.xs),
            _AmountLine(
              label: AppStrings.remaining,
              value: money.formatOrDash(assignment.balanceUnits, Currency.lyd),
            ),
            const SizedBox(height: AppSpacing.sm),
            GatedButton(
              buttonKey: Key('submit-${assignment.id}'),
              allowed: true,
              online: online,
              label: AppStrings.submitReceipt,
              onPressed: () => showAppForm<void>(
                context,
                _AssignmentForm(assignmentId: assignment.id),
              ),
            ),
          ],
        ),
      ),
    );
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
        Text(
          AppStrings.unlinkedReceipt,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('unlinked-name'),
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: AppStrings.customerName),
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('unlinked-amount'),
          controller: _amount,
          label: AppStrings.amount,
        ),
        const SizedBox(height: AppSpacing.md),
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
        Text(
          AppStrings.submitReceipt,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: Text(AppStrings.modeFull)),
            Switch(
              key: const Key('assignment-full'),
              value: _full,
              onChanged: (value) => setState(() => _full = value),
            ),
          ],
        ),
        if (!_full) ...[
          const SizedBox(height: AppSpacing.sm),
          UnitsField(controller: _amount, label: AppStrings.amount),
        ],
        const SizedBox(height: AppSpacing.md),
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
  });

  final CollectionSubmissionDto submission;
  final MoneyFormatter money;
  final bool manage;
  final bool cash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = submission.cashStatus == CashStatus.pending;
    final showDecide = manage && submission.status == 'pending';
    final showCash = cash && awaiting;
    return Card(
      key: Key('submission-${submission.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              submission.submittedByName ?? AppStrings.dash,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            _AmountLine(
              label: AppStrings.amount,
              value: money.formatOrDash(submission.amountUnits, Currency.lyd),
            ),
            Text(
              submission.mode == 'full'
                  ? AppStrings.modeFull
                  : AppStrings.modePartial,
            ),
            Text(collectionStatusLabel(submission.status, unlinked: false)),
            if (submission.createdAt != null)
              _IdLine(
                label: AppStrings.date,
                value: formatIsoDate(submission.createdAt),
              ),
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
            if (submission.cashReceivedAt != null)
              _IdLine(
                label: AppStrings.cashReceivedAt,
                value: formatIsoDate(submission.cashReceivedAt),
              ),
            if (showDecide || showCash) ...[
              const SizedBox(height: AppSpacing.sm),
              if (showDecide)
                GuardedMutation(
                  buttonKey: Key('approve-${submission.id}'),
                  inputs: 'approve:${submission.id}:${submission.version}',
                  expectedVersion: submission.version,
                  label: AppStrings.approve,
                  onSubmit: (meta) =>
                      _decide(context, ref, CollectionDecision.approve, meta),
                ),
              if (showDecide)
                GuardedMutation(
                  buttonKey: Key('reject-${submission.id}'),
                  inputs: 'reject:${submission.id}:${submission.version}',
                  expectedVersion: submission.version,
                  label: AppStrings.reject,
                  filled: false,
                  onSubmit: (meta) =>
                      _decide(context, ref, CollectionDecision.reject, meta),
                ),
              if (showCash)
                GuardedMutation(
                  buttonKey: Key('cash-${submission.id}'),
                  inputs: 'cash:${submission.id}:${submission.version}',
                  expectedVersion: submission.version,
                  label: AppStrings.cashReceived,
                  onSubmit: (meta) => _cash(context, ref, meta),
                ),
            ],
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
    required this.cash,
    required this.online,
  });

  final UnlinkedReceiptDto receipt;
  final MoneyFormatter money;
  final bool manage;
  final bool cash;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = receipt.cashStatus == CashStatus.pending;
    final ink = context.statusColors.onStatus;
    final showDecide = manage && receipt.status == 'pending';
    final showCash = cash && awaiting;
    return Card(
      key: Key('unlinked-card-${receipt.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      color: receipt.status == 'approved'
          ? context.statusColors.unlinkedApproved
          : context.statusColors.unlinkedPending,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(receipt.customerName, style: cairo(14, 700, color: ink)),
            const SizedBox(height: AppSpacing.xs),
            MoneyText(
              money.formatOrDash(receipt.amountUnits, Currency.lyd),
              style: context.textExtras.amount.copyWith(color: ink),
            ),
            Text(
              collectionStatusLabel(receipt.status, unlinked: true),
              style: cairo(12, 500, color: ink),
            ),
            if (awaiting)
              Text(
                AppStrings.awaitingCash,
                key: Key('awaiting-cash-${receipt.id}'),
                style: cairo(12, 800, color: ink),
              ),
            if (receipt.cashReceivedAt != null)
              _IdLine(
                label: AppStrings.cashReceivedAt,
                value: formatIsoDate(receipt.cashReceivedAt),
                color: ink,
              ),
            if (showDecide || showCash)
              _ActionSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDecide)
                      GuardedMutation(
                        buttonKey: Key('unlinked-approve-${receipt.id}'),
                        inputs: 'ulink:${receipt.id}:${receipt.version}',
                        expectedVersion: receipt.version,
                        label: AppStrings.approve,
                        onSubmit: (meta) => _decide(
                          context,
                          ref,
                          CollectionDecision.approve,
                          meta,
                        ),
                      ),
                    if (showDecide)
                      GatedButton(
                        buttonKey: Key('unlinked-link-${receipt.id}'),
                        allowed: true,
                        online: online,
                        filled: false,
                        label: AppStrings.link,
                        onPressed: () => showAppForm<void>(
                          context,
                          _LinkForm(receipt: receipt),
                        ),
                      ),
                    UnlinkedReceiptActions(receipt: receipt),
                  ],
                ),
              )
            else
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
        Text(AppStrings.link, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('link-customer'),
          controller: _customer,
          decoration: const InputDecoration(labelText: AppStrings.reference),
        ),
        const SizedBox(height: AppSpacing.md),
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
    final manage = permissions.canDo(ManagementAction.payrollManage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(manage ? AppStrings.payroll : AppStrings.myPayroll),
        payroll.when(
          loading: () =>
              const SkeletonBox(key: Key('payroll-loading'), height: 88),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(payrollProvider),
            retryKey: const Key('payroll-retry'),
          ),
          data: (data) {
            if (data.employees.isEmpty) {
              return const EmptyPane(
                key: Key('collections-empty-payroll'),
                message: AppStrings.emptyPayroll,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.period != null)
                  _IdLine(label: AppStrings.period, value: data.period!),
                for (final employee in data.employees)
                  _PayrollEmployee(employee: employee, money: money),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PayrollEmployee extends StatelessWidget {
  const _PayrollEmployee({required this.employee, required this.money});

  final PayrollEmployeeDto employee;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    String lyd(int? units) => money.formatOrDash(units, Currency.lyd);
    return Card(
      key: Key('payroll-${employee.userId}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employee.name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _AmountLine(
              label: AppStrings.baseSalary,
              value: lyd(employee.baseSalaryUnits),
            ),
            _AmountLine(
              label: AppStrings.openingCarry,
              value: lyd(employee.openingCarryUnits),
            ),
            _AmountLine(
              label: AppStrings.commissions,
              value: lyd(employee.commissionsUnits),
            ),
            _AmountLine(
              label: AppStrings.withdrawals,
              value: lyd(employee.withdrawalsUnits),
            ),
            _AmountLine(
              label: AppStrings.remaining,
              value: lyd(employee.remainingUnits),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSurface extends StatelessWidget {
  const _ActionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: child,
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    this.money = true,
  });

  final String label;
  final String value;
  final bool money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          _Figure(value: value, money: money),
        ],
      ),
    );
  }
}

class _IdLine extends StatelessWidget {
  const _IdLine({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label, style: style),
          LtrText(
            value,
            style: context.textExtras.tableNumber.copyWith(
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.money});

  final String value;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final style = context.textExtras.amount;
    if (money) return MoneyText(value, style: style);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(value, softWrap: true, style: style),
    );
  }
}

String _count(int? value) => value == null ? AppStrings.dash : '$value';

SectionKey? _knownSection(String? section) {
  if (section == null || section.isEmpty) return null;
  for (final key in SectionKey.values) {
    if (key.key == section) return key;
  }
  return null;
}

/// One column when the line is narrow or the text scale would clip a pair.
bool _tight(BuildContext context, double maxWidth) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return !maxWidth.isFinite || scale >= 1.3 || maxWidth < 320;
}
