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

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  static const screenKey = Key('screen-collections');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.collections)) return const ForbiddenPane();
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
        overview.when(
          loading: () => const SkeletonBox(key: Key('collections-loading')),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(collectionsProvider),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (manage) _Metrics(data: data, money: money),
              if (manage && data.employeeTotals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(AppStrings.employeeTotals, style: Theme.of(context).textTheme.titleSmall),
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
                Text(AppStrings.assignments, style: Theme.of(context).textTheme.titleSmall),
                for (final assignment in data.assignments)
                  _Assignment(assignment: assignment, money: money, online: online),
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
                _Unlinked(receipt: receipt, money: money, manage: manage, online: online),
              if (close && data.batchId != null)
                GatedButton(
                  buttonKey: const Key('close-batch'),
                  allowed: true,
                  online: online,
                  destructive: true,
                  label: AppStrings.closeBatch,
                  onPressed: () => _close(context, ref, data.batchId!),
                ),
              if (write || payroll) const _PayrollBlock(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _unlinked(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final amount = TextEditingController();
    await showAppForm<void>(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: AppStrings.customerName)),
          UnitsField(controller: amount, label: AppStrings.amount),
          FilledButton(
            onPressed: () async {
              final units = parseUnits(amount.text);
              if (units == null || name.text.trim().isEmpty) return;
              try {
                final ack = await ref.read(apiLayerProvider).collections.createUnlinkedReceipt(
                  customerName: name.text.trim(),
                  amountUnits: units,
                  meta: MutationMeta(),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
                );
                ref.invalidate(collectionsProvider);
                Navigator.of(context).pop();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
                );
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _close(BuildContext context, WidgetRef ref, String batchId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(AppStrings.closeBatchConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.confirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final ack = await ref.read(apiLayerProvider).collections.closeDay(
        batchId: batchId,
        meta: MutationMeta(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(collectionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
      );
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
      (AppStrings.collected, money.formatOrDash(data.collectedUnits, Currency.lyd)),
      (AppStrings.assignments, data.assignedCount == null ? AppStrings.dash : '${data.assignedCount}'),
      (AppStrings.dayTotal, money.formatOrDash(data.dayTotalUnits, Currency.lyd)),
      (AppStrings.pendingCount, data.pendingCount == null ? AppStrings.dash : '${data.pendingCount}'),
      (AppStrings.unlinkedCount, data.unlinkedPendingCount == null ? AppStrings.dash : '${data.unlinkedPendingCount}'),
      (AppStrings.cashOutstanding, money.formatOrDash(data.cashOutstandingUnits, Currency.lyd)),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final tile in tiles)
          SizedBox(
            width: 160,
            child: Card(
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
          ),
      ],
    );
  }
}

class _Assignment extends ConsumerWidget {
  const _Assignment({required this.assignment, required this.money, required this.online});

  final CollectionAssignmentDto assignment;
  final MoneyFormatter money;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(assignment.customerName),
        subtitle: Text(money.formatOrDash(assignment.balanceUnits, Currency.lyd)),
        trailing: GatedButton(
          buttonKey: Key('submit-${assignment.id}'),
          allowed: true,
          online: online,
          label: AppStrings.submitReceipt,
          onPressed: () => _submit(context, ref),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    var full = false;
    await showAppForm<void>(
      context,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text(AppStrings.modeFull),
              value: full,
              onChanged: (value) => setLocal(() => full = value),
            ),
            if (!full) UnitsField(controller: amount, label: AppStrings.amount),
            FilledButton(
              onPressed: () async {
                final units = full ? null : parseUnits(amount.text);
                if (!full && units == null) return;
                try {
                  final ack = await ref.read(apiLayerProvider).collections.submit(
                    assignment.id,
                    mode: full ? 'full' : 'partial',
                    amountUnits: units,
                    meta: MutationMeta(),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
                  );
                  ref.invalidate(collectionsProvider);
                  Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
                  );
                }
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
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
            Text(submission.mode == 'full' ? AppStrings.modeFull : AppStrings.modePartial),
            Text(collectionStatusLabel(submission.status, unlinked: false)),
            if (awaiting)
              Text(
                AppStrings.awaitingCash,
                key: const Key('awaiting-cash'),
                style: cairo(12, 800, color: context.statusColors.cashNegative),
              ),
            if (manage && submission.status == 'pending')
              Wrap(
                children: [
                  GatedButton(
                    buttonKey: Key('approve-${submission.id}'),
                    allowed: true,
                    online: online,
                    label: AppStrings.approve,
                    onPressed: () => _decide(context, ref, CollectionDecision.approve),
                  ),
                  GatedButton(
                    buttonKey: Key('reject-${submission.id}'),
                    allowed: true,
                    online: online,
                    filled: false,
                    label: AppStrings.reject,
                    onPressed: () => _decide(context, ref, CollectionDecision.reject),
                  ),
                ],
              ),
            if (cash && awaiting)
              GatedButton(
                buttonKey: Key('cash-${submission.id}'),
                allowed: true,
                online: online,
                label: AppStrings.cashReceived,
                onPressed: () => _cash(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, CollectionDecision decision) async {
    try {
      final ack = await ref.read(apiLayerProvider).collections.decide(
        submission.id,
        decision,
        meta: MutationMeta(expectedVersion: submission.version),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(collectionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
      );
    }
  }

  Future<void> _cash(BuildContext context, WidgetRef ref) async {
    try {
      final ack = await ref.read(apiLayerProvider).collections.markCashReceived(
        submission.id,
        MutationMeta(expectedVersion: submission.version),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(collectionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
      );
    }
  }
}

class _Unlinked extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      color: receipt.status == 'approved'
          ? context.statusColors.unlinkedApproved
          : context.statusColors.unlinkedPending,
      child: ListTile(
        title: Text(
          receipt.customerName,
          style: cairo(14, 700, color: context.statusColors.onStatus),
        ),
        subtitle: Text(
          '${money.formatOrDash(receipt.amountUnits, Currency.lyd)} · ${collectionStatusLabel(receipt.status, unlinked: true)}',
          style: cairo(12, 500, color: context.statusColors.onStatus),
        ),
      ),
    );
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
          permissions.canDo(ManagementAction.payrollManage) ? AppStrings.payroll : AppStrings.myPayroll,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        payroll.when(
          loading: () => const SkeletonBox(height: 64),
          error: (error, _) => Text(ref.read(errorHandlerProvider).toFailure(error).message),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.period != null) Text('${AppStrings.period} ${data.period}'),
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
