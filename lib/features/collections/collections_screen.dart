import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/collection_request_journal.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
import 'collection_card_tone.dart';
import 'collection_send.dart';
import 'collections_forms.dart';
import 'collections_payroll.dart';
import 'collections_strings.dart';
import 'phone_dialer.dart';
import 'unlinked_receipt_actions.dart';

/// استلامات الديون, matched to the deployed website server (537f073).
///
/// Admin (`collections.decide`): server metrics, employee totals, earlier
/// cash still to hand over, standalone receipts to link, the employees'
/// cards with their receipt history (approve / reject, then cash), and the
/// normal close of a settled batch. Employee: the same metrics, own
/// standalone receipts, own assigned cards with full / partial receipt.
/// Payroll for both. Every figure and colour comes from server fields.
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
    // Loads the saved receipt journal (survives an app restart).
    ref.watch(collectionRequestJournalProvider);
    final money = ref.watch(apiLayerProvider).money;
    final manage = permissions.canDo(ManagementAction.collectionsDecide);
    final write = permissions.canWrite(SectionKey.collections);
    final payroll = permissions.canDo(ManagementAction.payrollManage);
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      key: screenKey,
      padding: pagePadding(width).copyWith(bottom: AppSpacing.xxl),
      children: [
        const ScreenTitle(CollectionsText.title),
        Text(
          manage
              ? CollectionsText.adminDescription
              : CollectionsText.employeeDescription,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.look.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        KeptData<CollectionsOverviewDto>(
          value: overview,
          resetKey: 'collections',
          onRetry: () => ref.invalidate(collectionsProvider),
          messageOf: (error) =>
              failureText(ref.read(errorHandlerProvider).toFailure(error)),
          failureOf: (error) => ref.read(errorHandlerProvider).toFailure(error),
          loading: const _CollectionsLoading(),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(data: data, money: money),
              const SizedBox(height: AppSpacing.md),
              _Metrics(
                key: const Key('collections-metrics'),
                data: data,
                money: money,
              ),
              if (manage)
                _AdminBody(data: data, money: money)
              else if (write)
                _EmployeeBody(data: data, money: money),
              if (write || payroll || manage) const CollectionsPayrollBlock(),
            ],
          ),
        ),
      ],
    );
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
        SkeletonBox(height: 96),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 120),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 120),
      ],
    );
  }
}

/// The glossy headline: the server's approved total (`metrics.collectedUnits`).
class _Hero extends StatelessWidget {
  const _Hero({required this.data, required this.money});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gloss = look.glossHero;
    final radius = BorderRadius.circular(AppRadii.xxl);
    final batch = data.openBatches.isEmpty ? null : data.openBatches.first;
    return DecoratedBox(
      key: const Key('collections-hero'),
      decoration: gloss
          .decoration(radius)
          .copyWith(boxShadow: gloss.glowShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: GlossSheen(
          gloss: gloss,
          radius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CollectionsText.totalApproved,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: look.onHeroMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: MoneyText(
                    money.formatOrDash(data.collectedUnits, Currency.lyd),
                    key: const Key('collections-hero-amount'),
                    style: context.textExtras.amountLarge.copyWith(
                      color: look.heroFigure,
                    ),
                  ),
                ),
                if (batch != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    CollectionsText.batchLabel(
                      batch.businessDate,
                      batch.batchNumber,
                    ),
                    style: cairo(12, 600, color: look.onHeroMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data, required this.money, super.key});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final tiles = <(String, String, String, bool, Gloss)>[
      (
        'assigned',
        CollectionsText.assigned,
        _count(data.assignedCount),
        false,
        look.glossBlue,
      ),
      (
        'executed',
        CollectionsText.executed,
        _count(data.executedCount),
        false,
        look.glossGreen,
      ),
      (
        'pending',
        CollectionsText.pending,
        _count(data.pendingCount),
        false,
        look.glossViolet,
      ),
      (
        'unlinked',
        CollectionsText.unlinked,
        _count(data.unlinkedPendingCount),
        false,
        look.glossGrey,
      ),
      (
        'cash',
        CollectionsText.cashOutstanding,
        money.formatOrDash(data.cashOutstandingUnits, Currency.lyd),
        true,
        look.glossDebt,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _tight(context, width) ? 1 : 2;
        const gap = AppSpacing.sm;
        final tileWidth = columns == 1 ? width : (width - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tile.$1 == 'cash' && columns == 2 ? width : tileWidth,
                child: _MetricTile(
                  key: Key('metric-${tile.$1}'),
                  label: tile.$2,
                  value: tile.$3,
                  money: tile.$4,
                  gloss: tile.$5,
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
    required this.gloss,
    super.key,
  });

  final String label;
  final String value;
  final bool money;
  final Gloss gloss;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.xl);
    final style = context.textExtras.amount.copyWith(color: gloss.amount);
    return DecoratedBox(
      decoration: gloss
          .decoration(radius)
          .copyWith(boxShadow: gloss.glowShadow),
      child: ClipRRect(
        borderRadius: radius,
        child: GlossSheen(
          gloss: gloss,
          radius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: cairo(12, 600, color: gloss.ink)),
                const SizedBox(height: AppSpacing.xs),
                if (money)
                  MoneyText(value, style: style)
                else
                  Text(value, textDirection: TextDirection.ltr, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- admin

class _AdminBody extends ConsumerWidget {
  const _AdminBody({required this.data, required this.money});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final cash = permissions.canDo(ManagementAction.collectionsCashReceived);
    final close = permissions.canDo(ManagementAction.collectionsCloseDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.employeeTotals.isNotEmpty) ...[
          const CollectionsHeading(
            CollectionsText.employeeTotals,
            note: CollectionsText.employeeTotalsNote,
          ),
          _EmployeeTotals(rows: data.employeeTotals, money: money),
        ],
        if (data.outstandingCash.isNotEmpty) ...[
          const CollectionsHeading(
            CollectionsText.outstandingTitle,
            note: CollectionsText.outstandingNote,
          ),
          for (final item in data.outstandingCash)
            _OutstandingRow(item: item, money: money, cash: cash),
        ],
        if (data.unlinkedReceipts.isNotEmpty) ...[
          const CollectionsHeading(
            CollectionsText.unlinkedAdminTitle,
            note: CollectionsText.unlinkedAdminNote,
          ),
          for (final receipt in data.unlinkedReceipts)
            _AdminUnlinkedCard(receipt: receipt, money: money),
        ],
        const CollectionsHeading(CollectionsText.followTitle),
        if (data.assignments.isEmpty)
          const EmptyPane(
            key: Key('collections-empty-assignments'),
            message: CollectionsText.noCards,
          )
        else
          for (final assignment in data.assignments)
            _AssignmentCard(
              assignment: assignment,
              history: _history(data, assignment.id),
              money: money,
              admin: true,
            ),
        if (close && data.openBatches.isNotEmpty)
          _CloseBatch(data: data, money: money),
      ],
    );
  }
}

/// The website's card history: this card's submissions, oldest first,
/// rejected ones left out.
List<CollectionSubmissionDto> _history(
  CollectionsOverviewDto data,
  String assignmentId,
) => [
  for (final row in data.submissions.reversed)
    if (row.assignmentId == assignmentId && row.status != 'rejected') row,
];

class _EmployeeTotals extends StatelessWidget {
  const _EmployeeTotals({required this.rows, required this.money});

  final List<EmployeeTotalDto> rows;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Column(
      key: const Key('employee-totals'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          CollectionsPanel(
            key: Key('employee-total-${row.employeeId ?? row.employeeName}'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.employeeName,
                        style: cairo(15, 700, color: look.ink),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${CollectionsText.approvedShort} ${_count(row.approvedCount)} · '
                        '${CollectionsText.waitingShort} ${_count(row.pendingCount)}',
                        style: cairo(12, 500, color: look.muted),
                      ),
                    ],
                  ),
                ),
                MoneyText(
                  money.formatOrDash(row.collectedUnits, Currency.lyd),
                  style: context.textExtras.amount.copyWith(color: look.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OutstandingRow extends ConsumerWidget {
  const _OutstandingRow({
    required this.item,
    required this.money,
    required this.cash,
  });

  final OutstandingCashDto item;
  final MoneyFormatter money;
  final bool cash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
    return CollectionsPanel(
      key: Key('outstanding-${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [item.customerName, ?item.collectorName].join(' — '),
            style: cairo(14, 700, color: look.ink),
          ),
          MoneyText(
            money.formatOrDash(item.amountUnits, Currency.lyd),
            style: context.textExtras.amount.copyWith(color: look.danger),
          ),
          if (cash) ...[
            const SizedBox(height: AppSpacing.sm),
            GuardedMutation(
              buttonKey: Key('outstanding-cash-${item.id}'),
              inputs: 'cash:${item.id}',
              label: CollectionsText.cashReceived,
              onVersionConflict: () => ref.invalidate(collectionsProvider),
              onSubmit: (meta) async {
                await ref
                    .read(apiLayerProvider)
                    .collections
                    .markCashReceived(item.id, meta);
                ref.invalidate(collectionsProvider);
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminUnlinkedCard extends ConsumerWidget {
  const _AdminUnlinkedCard({required this.receipt, required this.money});

  final UnlinkedReceiptDto receipt;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
    final online = ref.watch(onlineProvider);
    final decide = permissionsOf(ref).canDo(ManagementAction.collectionsDecide);
    final pending = receipt.status == 'pending';
    final gloss = switch (receipt.status) {
      'approved' => look.glossCredit,
      'rejected' => look.glossGrey,
      _ => look.glossViolet,
    };
    final state = switch (receipt.status) {
      'pending' => CollectionsText.unlinked,
      'approved' => CollectionsText.unlinkedApproved,
      _ => CollectionsText.unlinkedRejected,
    };
    return GlossCard(
      key: Key('unlinked-card-${receipt.id}'),
      gloss: gloss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            name: receipt.customerName,
            subtitle: receipt.collectorName,
            amount: money.formatOrDash(receipt.amountUnits, Currency.lyd),
            gloss: gloss,
          ),
          const SizedBox(height: AppSpacing.sm),
          _HistoryLine(
            gloss: gloss,
            title: state,
            trailing: receipt.businessDate,
            status: receipt.awaitingCash
                ? _AwaitingCash(id: receipt.id, gloss: gloss)
                : receipt.cashReceivedAt != null
                ? _Badge(
                    key: Key('cash-done-${receipt.id}'),
                    text: CollectionsText.cashReceived,
                    gloss: gloss,
                  )
                : receipt.status == 'rejected'
                ? _Badge(text: CollectionsText.rejectedNoEffect, gloss: gloss)
                : null,
          ),
          if (decide && pending) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                GatedButton(
                  buttonKey: Key('unlinked-link-${receipt.id}'),
                  allowed: true,
                  online: online,
                  label: CollectionsText.existingCustomer,
                  onPressed: () => showAppForm<void>(
                    context,
                    LinkReceiptForm(receipt: receipt, createNew: false),
                  ),
                ),
                GatedButton(
                  buttonKey: Key('unlinked-new-${receipt.id}'),
                  allowed: true,
                  online: online,
                  filled: false,
                  label: CollectionsText.newCustomer,
                  onPressed: () => showAppForm<void>(
                    context,
                    LinkReceiptForm(receipt: receipt, createNew: true),
                  ),
                ),
              ],
            ),
          ],
          UnlinkedReceiptActions(receipt: receipt),
        ],
      ),
    );
  }
}

class _CloseBatch extends ConsumerStatefulWidget {
  const _CloseBatch({required this.data, required this.money});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  ConsumerState<_CloseBatch> createState() => _CloseBatchState();
}

class _CloseBatchState extends ConsumerState<_CloseBatch> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final batches = widget.data.openBatches;
    final batch = batches.firstWhere(
      (b) => b.id == _selected,
      orElse: () => batches.first,
    );
    final look = context.look;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CollectionsHeading(CollectionsText.closeBatch),
        CollectionsPanel(
          key: const Key('close-batch-panel'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (batches.length > 1)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final b in batches)
                      ChoiceChip(
                        key: Key('close-batch-pick-${b.id}'),
                        selected: b.id == batch.id,
                        label: Text(
                          CollectionsText.batchLabel(
                            b.businessDate,
                            b.batchNumber,
                          ),
                        ),
                        onSelected: (_) => setState(() => _selected = b.id),
                      ),
                  ],
                )
              else
                Text(
                  CollectionsText.batchLabel(
                    batch.businessDate,
                    batch.batchNumber,
                  ),
                  style: cairo(13, 600, color: look.muted),
                ),
              const SizedBox(height: AppSpacing.sm),
              GuardedMutation(
                buttonKey: const Key('close-batch'),
                inputs: 'close:${batch.id}',
                label: CollectionsText.closeBatch,
                confirmText: CollectionsText.closeConfirm,
                destructive: true,
                onVersionConflict: () => ref.invalidate(collectionsProvider),
                onSubmit: (meta) => _close(batch.id, meta),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _close(String batchId, MutationMeta meta) async {
    try {
      await ref
          .read(apiLayerProvider)
          .collections
          .closeDay(batchId: batchId, meta: meta);
    } on ConflictException catch (error) {
      // COLLECTION_DAY_NOT_SETTLED: the server message names what is left.
      ref.invalidate(collectionsProvider);
      return error.message;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(CollectionsText.batchClosed)),
      );
    }
    ref.invalidate(collectionsProvider);
    return null;
  }
}

// ------------------------------------------------------------- employee

class _EmployeeBody extends ConsumerWidget {
  const _EmployeeBody({required this.data, required this.money});

  final CollectionsOverviewDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        GatedButton(
          buttonKey: const Key('unlinked-collection'),
          allowed: true,
          online: online,
          label: CollectionsText.createStandalone,
          onPressed: () =>
              showAppForm<void>(context, const UnlinkedReceiptForm()),
        ),
        if (data.outstandingCash.isNotEmpty) ...[
          const CollectionsHeading(
            CollectionsText.outstandingTitle,
            note: CollectionsText.outstandingNote,
          ),
          for (final item in data.outstandingCash)
            _OutstandingRow(item: item, money: money, cash: false),
        ],
        if (data.unlinkedReceipts.isNotEmpty) ...[
          const CollectionsHeading(CollectionsText.myUnlinkedTitle),
          for (final receipt in data.unlinkedReceipts)
            _EmployeeUnlinkedCard(receipt: receipt, money: money),
        ],
        const CollectionsHeading(CollectionsText.myCardsTitle),
        if (data.assignments.isEmpty)
          const EmptyPane(
            key: Key('collections-empty-assignments'),
            message: CollectionsText.noMyCards,
          )
        else
          for (final assignment in data.assignments)
            _AssignmentCard(
              assignment: assignment,
              history: _history(data, assignment.id),
              money: money,
              admin: false,
            ),
      ],
    );
  }
}

class _EmployeeUnlinkedCard extends StatelessWidget {
  const _EmployeeUnlinkedCard({required this.receipt, required this.money});

  final UnlinkedReceiptDto receipt;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gloss = switch (receipt.status) {
      'approved' => look.glossCredit,
      'rejected' => look.glossGrey,
      _ => look.glossViolet,
    };
    final state = switch (receipt.status) {
      'pending' => CollectionsText.myUnlinkedPending,
      'approved' => CollectionsText.unlinkedApproved,
      _ => CollectionsText.rejectedByAdmin,
    };
    return GlossCard(
      key: Key('unlinked-card-${receipt.id}'),
      gloss: gloss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            name: receipt.customerName,
            subtitle: receipt.collectorName,
            amount: money.formatOrDash(receipt.amountUnits, Currency.lyd),
            gloss: gloss,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(state, style: cairo(12, 600, color: gloss.ink)),
          if (receipt.status == 'approved')
            receipt.cashReceivedAt == null
                ? Text(
                    CollectionsText.waitingCashFromAdmin,
                    key: ValueKey('awaiting-cash-${receipt.id}'),
                    style: cairo(12, 800, color: gloss.ink),
                  )
                : Text(
                    CollectionsText.cashReceived,
                    key: Key('cash-done-${receipt.id}'),
                    style: cairo(12, 800, color: gloss.ink),
                  ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- assigned cards

class _AssignmentCard extends ConsumerWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.history,
    required this.money,
    required this.admin,
  });

  final CollectionAssignmentDto assignment;
  final List<CollectionSubmissionDto> history;
  final MoneyFormatter money;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = collectionCardTone(assignment);
    final gloss = collectionToneGloss(context, tone);
    var partial = 0;
    return GlossCard(
      key: Key('assignment-${assignment.id}'),
      gloss: gloss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox.shrink(
            key: Key('tone-${assignment.id}-${collectionToneName(tone)}'),
          ),
          _CardHeader(
            name: assignment.customerName,
            subtitle: assignment.assigneeName,
            amount: money.formatOrDash(assignment.balanceUnits, Currency.lyd),
            gloss: gloss,
            amountKey: Key('assignment-balance-${assignment.id}'),
          ),
          if (!admin) ...[
            const SizedBox(height: AppSpacing.xxs),
            LtrText(
              assignment.phone ?? CollectionsText.noPhone,
              key: Key('phone-${assignment.id}'),
              style: cairo(12, 600, color: gloss.ink),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (history.isEmpty && admin)
            Text(
              CollectionsText.noHistory,
              style: cairo(12, 500, color: gloss.ink),
            ),
          for (final item in history)
            _SubmissionLine(
              submission: item,
              title: item.mode == 'full'
                  ? CollectionsText.fullReceipt
                  : CollectionsText.partialReceiptN(++partial),
              money: money,
              gloss: gloss,
              admin: admin,
            ),
          if (!admin) _EmployeeActions(assignment: assignment, money: money),
        ],
      ),
    );
  }
}

class _SubmissionLine extends ConsumerWidget {
  const _SubmissionLine({
    required this.submission,
    required this.title,
    required this.money,
    required this.gloss,
    required this.admin,
  });

  final CollectionSubmissionDto submission;
  final String title;
  final MoneyFormatter money;
  final Gloss gloss;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final decide =
        admin && permissions.canDo(ManagementAction.collectionsDecide);
    final cash =
        admin && permissions.canDo(ManagementAction.collectionsCashReceived);
    final pending = submission.status == 'pending';
    final awaiting = submission.awaitingCash;
    return Padding(
      key: Key('submission-${submission.id}'),
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: _HistoryLine(
        gloss: gloss,
        title: title,
        amount: money.formatOrDash(submission.amountUnits, Currency.lyd),
        status: pending
            ? _Badge(text: CollectionsText.awaitingApproval, gloss: gloss)
            : awaiting
            ? _AwaitingCash(
                id: submission.id,
                gloss: gloss,
                // Employee wording from the website's employee section.
                text: admin
                    ? CollectionsText.awaitingCash
                    : CollectionsText.waitingCashFromAdmin,
              )
            : submission.cashReceivedAt != null
            ? _Badge(
                key: Key('cash-done-${submission.id}'),
                text: CollectionsText.cashReceived,
                gloss: gloss,
              )
            : null,
        actions: [
          if (decide && pending) ...[
            GuardedMutation(
              buttonKey: Key('approve-${submission.id}'),
              inputs: 'approve:${submission.id}',
              label: AppStrings.approve,
              onVersionConflict: () => ref.invalidate(collectionsProvider),
              onSubmit: (meta) =>
                  _decide(ref, CollectionDecision.approve, meta),
            ),
            GuardedMutation(
              buttonKey: Key('reject-${submission.id}'),
              inputs: 'reject:${submission.id}',
              label: AppStrings.reject,
              filled: false,
              onVersionConflict: () => ref.invalidate(collectionsProvider),
              onSubmit: (meta) => _decide(ref, CollectionDecision.reject, meta),
            ),
          ],
          if (cash && awaiting)
            GuardedMutation(
              buttonKey: Key('cash-${submission.id}'),
              inputs: 'cash:${submission.id}',
              label: CollectionsText.cashReceived,
              onVersionConflict: () => ref.invalidate(collectionsProvider),
              onSubmit: (meta) async {
                await ref
                    .read(apiLayerProvider)
                    .collections
                    .markCashReceived(submission.id, meta);
                ref.invalidate(collectionsProvider);
                return null;
              },
            ),
        ],
      ),
    );
  }

  Future<String?> _decide(
    WidgetRef ref,
    CollectionDecision decision,
    MutationMeta meta,
  ) async {
    await ref
        .read(apiLayerProvider)
        .collections
        .decide(submission.id, decision, meta: meta);
    ref.invalidate(collectionsProvider);
    return null;
  }
}

/// استلام كلي / استلام جزئي / the phone, as on the website. A send whose
/// reply was lost locks the card to one «إعادة الإرسال» with the saved
/// inputs until the server answers.
class _EmployeeActions extends ConsumerWidget {
  const _EmployeeActions({required this.assignment, required this.money});

  final CollectionAssignmentDto assignment;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(collectionRequestJournalProvider);
    final online = ref.watch(onlineProvider);
    final open = ref
        .read(collectionRequestJournalProvider.notifier)
        .pending(collectionsUserId(ref), submitSlot(assignment.id));
    final balance = assignment.balanceUnits?.asInt;
    final inactive = balance == null || balance <= 0;
    final blocked = inactive || assignment.hasPending;
    final phone = assignment.phone;

    if (open != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CollectionsText.unconfirmed,
            key: Key('unconfirmed-${assignment.id}'),
            style: cairo(
              12,
              700,
              color: collectionToneGloss(
                context,
                collectionCardTone(assignment),
              ).ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GuardedMutation(
            buttonKey: Key('retry-${assignment.id}'),
            inputs: 'retry:${assignment.id}:${open.fingerprint}',
            label:
                '${CollectionsText.retrySend} (${open.mode == 'full' ? CollectionsText.fullReceipt : CollectionsText.partialReceipt} '
                '${money.formatOrDash(open.amountUnits, Currency.lyd)})',
            onVersionConflict: () => ref.invalidate(collectionsProvider),
            onSubmit: (_) => _send(context, ref, open.mode, open.amountUnits!),
          ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (blocked)
          FilledButton(
            key: Key('full-${assignment.id}'),
            onPressed: null,
            child: const Text(CollectionsText.fullReceipt),
          )
        else
          GuardedMutation(
            buttonKey: Key('full-${assignment.id}'),
            inputs: 'full:${assignment.id}:$balance',
            label: CollectionsText.fullReceipt,
            confirmText: CollectionsText.fullConfirm(
              money.formatOrDash(assignment.balanceUnits, Currency.lyd),
            ),
            onVersionConflict: () => ref.invalidate(collectionsProvider),
            // 537f073 expects the current debt with a full receipt and
            // refuses it if the debt changed (FULL_AMOUNT_CHANGED).
            onSubmit: (_) => _send(context, ref, 'full', balance),
          ),
        OutlinedButton(
          key: Key('submit-${assignment.id}'),
          onPressed: blocked || !online
              ? null
              : () => showAppForm<void>(
                  context,
                  PartialReceiptForm(assignment: assignment),
                ),
          child: const Text(CollectionsText.partialReceipt),
        ),
        OutlinedButton.icon(
          key: Key('call-${assignment.id}'),
          onPressed: inactive || phone == null || phone.isEmpty
              ? null
              : () async {
                  // Opens the dialer (tel:), as the website's link does.
                  // Without a dialer the number is copied instead.
                  final dialed = await ref.read(phoneDialerProvider)(phone);
                  if (dialed) return;
                  await Clipboard.setData(ClipboardData(text: phone));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(CollectionsText.phoneCopied),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.phone_outlined, size: 16),
          label: const Text(CollectionsText.call),
        ),
      ],
    );
  }

  Future<String?> _send(
    BuildContext context,
    WidgetRef ref,
    String mode,
    int amountUnits,
  ) async {
    final outcome = await sendAssignmentReceipt(
      ref,
      assignmentId: assignment.id,
      mode: mode,
      amountUnits: amountUnits,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome == CollectionSendOutcome.alreadyRecorded
                ? CollectionsText.alreadyRecorded
                : CollectionsText.sent,
          ),
        ),
      );
    }
    return null;
  }
}

// --------------------------------------------------------------- pieces

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.name,
    required this.amount,
    required this.gloss,
    this.subtitle,
    this.amountKey,
  });

  final String name;
  final String? subtitle;
  final String amount;
  final Gloss gloss;
  final Key? amountKey;

  /// Name, the employee, then the balance on its own line at the start, so
  /// a long name never pushes the figure off a narrow card.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: cairo(16, 800, color: gloss.ink)),
        if (subtitle != null)
          Text(
            subtitle!,
            style: cairo(12, 500, color: gloss.ink.withValues(alpha: 0.8)),
          ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: MoneyText(
            amount,
            key: amountKey,
            style: context.textExtras.amount.copyWith(color: gloss.amount),
          ),
        ),
      ],
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({
    required this.gloss,
    required this.title,
    this.amount,
    this.trailing,
    this.status,
    this.actions = const [],
  });

  final Gloss gloss;
  final String title;
  final String? amount;
  final String? trailing;
  final Widget? status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gloss.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: gloss.ink.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: cairo(13, 700, color: gloss.ink)),
            if (amount != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MoneyText(
                  amount!,
                  style: cairo(14, 800, color: gloss.amount),
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (trailing != null)
                  LtrText(trailing!, style: cairo(12, 500, color: gloss.ink)),
                ?status,
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _ActionSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AwaitingCash extends StatelessWidget {
  const _AwaitingCash({
    required this.id,
    required this.gloss,
    this.text = CollectionsText.awaitingCash,
  });

  final String id;
  final Gloss gloss;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      key: ValueKey('awaiting-cash-$id'),
      text: text,
      gloss: gloss,
      strong: true,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.gloss,
    this.strong = false,
    super.key,
  });

  final String text;
  final Gloss gloss;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gloss.ink.withValues(alpha: strong ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          text,
          style: cairo(11, strong ? 800 : 600, color: gloss.ink),
        ),
      ),
    );
  }
}

/// Buttons sit on the page surface, not on the coloured card, so they keep
/// the theme's contrast on every card tone.
class _ActionSurface extends StatelessWidget {
  const _ActionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: look.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
        child: child,
      ),
    );
  }
}

/// A glossy card: gradient, sheen, border and glow of [gloss].
class GlossCard extends StatelessWidget {
  const GlossCard({required this.gloss, required this.child, super.key});

  final Gloss gloss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.card);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: gloss
            .decoration(radius)
            .copyWith(boxShadow: gloss.glowShadow),
        child: ClipRRect(
          borderRadius: radius,
          child: GlossSheen(
            gloss: gloss,
            radius: radius,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain theme panel (glass in dark, white card in light).
class CollectionsPanel extends StatelessWidget {
  const CollectionsPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: look.cardBorder),
          boxShadow: look.glass
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

class CollectionsHeading extends StatelessWidget {
  const CollectionsHeading(this.text, {this.note, super.key});

  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: cairo(16, 800, color: look.ink)),
          if (note != null)
            Text(note!, style: cairo(12, 500, color: look.muted)),
        ],
      ),
    );
  }
}

String _count(int? value) => value == null ? AppStrings.dash : '$value';

/// One column when the line is narrow or the text scale would clip a pair.
bool _tight(BuildContext context, double maxWidth) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return !maxWidth.isFinite || scale >= 1.3 || maxWidth < 320;
}
