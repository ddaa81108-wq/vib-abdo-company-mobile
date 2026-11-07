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
import 'collections_export.dart';
import 'collections_strings.dart';
import 'collections_view_model.dart';
import 'phone_dialer.dart';
import 'unlinked_receipt_actions.dart';

/// استلامات الديون, matched to the deployed website server (537f073) and
/// laid out after Ali's two pictures (2026-11-03), in the app's own dark and
/// light theme.
///
/// Admin (`collections.decide`): filter card (batch, employee, search),
/// action bar (payroll, close, PDF), the batch close note, four summary
/// cards, four tabs with counts and the chosen tab's list. Employee: action
/// bar (standalone receipt, payroll, PDF), own counts, the cash to hand
/// over, three tabs, search and the list. Payroll opens from the bar.
/// Every figure is a server field or derived from the server's lists; see
/// `collections_view_model.dart`.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  static const screenKey = Key('screen-collections');

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  var _payroll = false;

  @override
  Widget build(BuildContext context) {
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
    final showPayroll = write || payroll || manage;
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      key: CollectionsScreen.screenKey,
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
        if (_payroll && showPayroll) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('collections-payroll-back'),
              onPressed: () => setState(() => _payroll = false),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(CollectionsText.payrollBack),
            ),
          ),
          const CollectionsPayrollBlock(),
        ] else
          KeptData<CollectionsOverviewDto>(
            value: overview,
            resetKey: 'collections',
            onRetry: () => ref.invalidate(collectionsProvider),
            messageOf: (error) =>
                failureText(ref.read(errorHandlerProvider).toFailure(error)),
            failureOf: (error) =>
                ref.read(errorHandlerProvider).toFailure(error),
            loading: const _CollectionsLoading(),
            builder: (data) => manage
                ? _AdminView(
                    data: data,
                    money: money,
                    onPayroll: showPayroll
                        ? () => setState(() => _payroll = true)
                        : null,
                  )
                : _EmployeeView(
                    data: data,
                    money: money,
                    write: write,
                    onPayroll: showPayroll
                        ? () => setState(() => _payroll = true)
                        : null,
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

// ---------------------------------------------------------------- admin

class _AdminView extends ConsumerStatefulWidget {
  const _AdminView({
    required this.data,
    required this.money,
    required this.onPayroll,
  });

  final CollectionsOverviewDto data;
  final MoneyFormatter money;
  final VoidCallback? onPayroll;

  @override
  ConsumerState<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends ConsumerState<_AdminView> {
  String? _batchId;
  String? _employee;
  var _tab = AdminTab.all;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final money = widget.money;
    final batches = data.openBatches;
    // A batch that was closed meanwhile falls back to the newest open one.
    final batch =
        batches.where((b) => b.id == _batchId).firstOrNull ??
        batches.firstOrNull;
    final employees = employeeOptions(data);
    final employee = employees.contains(_employee) ? _employee : null;
    final filter = CollectionsFilter(
      batchId: batch?.id,
      employee: employee,
      query: _search.text,
    );
    final summary = CollectionsSummary.of(data, filter);
    final settlement = BatchSettlement.of(data, batch?.id);
    final rows = {
      for (final tab in AdminTab.values) tab: adminTabRows(data, filter, tab),
    };
    final permissions = permissionsOf(ref);
    final close = permissions.canDo(ManagementAction.collectionsCloseDay);
    final look = context.look;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionsPanel(
          key: const Key('collections-filter-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldPair(
                first: _LabeledField(
                  label: CollectionsText.filterBatch,
                  child: DropdownButtonFormField<String>(
                    key: const Key('collections-filter-batch'),
                    initialValue: batch?.id,
                    isExpanded: true,
                    hint: const Text(CollectionsText.noOpenBatches),
                    items: [
                      for (final b in batches)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            CollectionsText.batchLabel(
                              b.businessDate,
                              b.batchNumber,
                            ),
                            overflow: TextOverflow.ellipsis,
                            style: cairo(13, 700, color: look.ink),
                          ),
                        ),
                    ],
                    onChanged: batches.isEmpty
                        ? null
                        : (id) => setState(() => _batchId = id),
                  ),
                ),
                second: _LabeledField(
                  label: CollectionsText.filterEmployee,
                  child: DropdownButtonFormField<String?>(
                    key: const Key('collections-filter-employee'),
                    initialValue: employee,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          CollectionsText.allEmployees,
                          style: cairo(13, 700, color: look.ink),
                        ),
                      ),
                      for (final name in employees)
                        DropdownMenuItem<String?>(
                          value: name,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: cairo(13, 700, color: look.ink),
                          ),
                        ),
                    ],
                    onChanged: (name) => setState(() => _employee = name),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(
                label: CollectionsText.searchView,
                child: TextField(
                  key: const Key('collections-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: CollectionsText.searchViewHint,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActionBar(
                key: const Key('collections-action-bar'),
                children: [
                  if (widget.onPayroll != null)
                    _BarButton(
                      buttonKey: const Key('collections-payroll'),
                      label: CollectionsText.payrollButton,
                      onPressed: widget.onPayroll,
                    ),
                  if (close) _CloseBatchButton(batch: batch),
                  CollectionsExportButton(
                    data: data,
                    admin: true,
                    batchId: batch?.id,
                    label: CollectionsText.exportBatch,
                    icon: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: look.cardBorder, height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                CollectionsText.closeBatchTitle,
                style: cairo(15, 800, color: look.ink),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                CollectionsText.closeScopeNote,
                style: cairo(12, 500, color: look.muted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                key: const Key('close-batch-note'),
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.xxs,
                children: [
                  Text(
                    CollectionsText.reviewCount(settlement.reviewCount),
                    key: const Key('close-batch-review'),
                    style: cairo(13, 600, color: look.ink),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${CollectionsText.cashNotReceived} ',
                        style: cairo(13, 600, color: look.ink),
                      ),
                      MoneyText(
                        _money(money, settlement.cashUnits),
                        key: const Key('close-batch-cash'),
                        style: cairo(13, 700, color: look.ink),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Grid2(
          key: const Key('collections-metrics'),
          children: [
            _SummaryCard(
              key: const Key('metric-approved'),
              title: CollectionsText.sumApproved,
              value: _money(money, summary.approvedUnits),
              money: true,
              edge: look.accent,
            ),
            _SummaryCard(
              key: const Key('metric-cash-received'),
              title: CollectionsText.sumCashReceived,
              value: _money(money, summary.cashReceivedUnits),
              money: true,
              edge: look.success,
            ),
            _SummaryCard(
              key: const Key('metric-remaining'),
              title: CollectionsText.sumRemaining,
              value: _money(money, summary.remainingUnits),
              money: true,
              edge: _amber(context),
            ),
            _SummaryCard(
              key: const Key('metric-pending'),
              title: CollectionsText.sumPending,
              value: '${summary.pendingCount}',
              unit: CollectionsText.operations,
              note: CollectionsText.unlinkedWithin(
                summary.unlinkedPendingCount,
              ),
              edge: look.violet,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CollectionsText.summaryNote,
          style: cairo(12, 500, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        _Grid2(
          key: const Key('collections-tabs'),
          tight: true,
          children: [
            for (final tab in AdminTab.values)
              _TabChip(
                key: Key('collections-tab-${tab.name}'),
                countKey: Key('collections-tab-count-${tab.name}'),
                label: _adminTabLabel(tab),
                count: rows[tab]!.count,
                selected: _tab == tab,
                onTap: () => setState(() => _tab = tab),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ListCard(
          key: const Key('collections-list'),
          title: _adminTabLabel(_tab),
          trailing: const _SyncStatus(),
          child: _AdminList(
            data: data,
            rows: rows[_tab]!,
            money: money,
            empty: _search.text.trim().isNotEmpty
                ? CollectionsText.noMatch
                : switch (_tab) {
                    AdminTab.all => CollectionsText.noCards,
                    AdminTab.review => CollectionsText.emptyReview,
                    AdminTab.cash => CollectionsText.emptyCash,
                    AdminTab.previous => CollectionsText.emptyPrevious,
                  },
          ),
        ),
        if (data.employeeTotals.isNotEmpty)
          _EmployeeTotalsSection(rows: data.employeeTotals, money: money),
      ],
    );
  }
}

/// 537 `employeeTotals` (admin only), kept under the list as before.
class _EmployeeTotalsSection extends StatelessWidget {
  const _EmployeeTotalsSection({required this.rows, required this.money});

  final List<EmployeeTotalDto> rows;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CollectionsHeading(
          CollectionsText.employeeTotals,
          note: CollectionsText.employeeTotalsNote,
        ),
        _EmployeeTotals(rows: rows, money: money),
      ],
    );
  }
}

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
                        '${CollectionsText.approvedShort} ${row.approvedCount ?? AppStrings.dash} · '
                        '${CollectionsText.waitingShort} ${row.pendingCount ?? AppStrings.dash}',
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

String _adminTabLabel(AdminTab tab) => switch (tab) {
  AdminTab.all => CollectionsText.tabAll,
  AdminTab.review => CollectionsText.tabReview,
  AdminTab.cash => CollectionsText.tabCash,
  AdminTab.previous => CollectionsText.tabPrevious,
};

class _AdminList extends ConsumerWidget {
  const _AdminList({
    required this.data,
    required this.rows,
    required this.money,
    required this.empty,
  });

  final CollectionsOverviewDto data;
  final AdminTabRows rows;
  final MoneyFormatter money;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = permissionsOf(ref)
        .canDo(ManagementAction.collectionsCashReceived);
    if (rows.isEmpty) {
      return _EmptyLine(
        key: const Key('collections-empty-assignments'),
        text: empty,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final assignment in rows.assignments)
          _AssignmentCard(
            assignment: assignment,
            history: collectionCardHistory(data, assignment.id),
            money: money,
            admin: true,
          ),
        for (final receipt in rows.unlinked)
          _AdminUnlinkedCard(receipt: receipt, money: money),
        for (final item in rows.outstanding)
          _OutstandingRow(item: item, money: money, cash: cash),
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

// ------------------------------------------------------------- employee

class _EmployeeView extends ConsumerStatefulWidget {
  const _EmployeeView({
    required this.data,
    required this.money,
    required this.write,
    required this.onPayroll,
  });

  final CollectionsOverviewDto data;
  final MoneyFormatter money;
  final bool write;
  final VoidCallback? onPayroll;

  @override
  ConsumerState<_EmployeeView> createState() => _EmployeeViewState();
}

class _EmployeeViewState extends ConsumerState<_EmployeeView> {
  var _tab = EmployeeTab.cards;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final money = widget.money;
    final online = ref.watch(onlineProvider);
    final look = context.look;
    final rows = employeeTabRows(data, _search.text, _tab);
    final title = switch (_tab) {
      EmployeeTab.cards => CollectionsText.myCardsTitle,
      EmployeeTab.receipts => CollectionsText.tabMyReceipts,
      EmployeeTab.cash => CollectionsText.cashToHand,
    };
    final empty = _search.text.trim().isNotEmpty
        ? CollectionsText.noMatch
        : switch (_tab) {
            EmployeeTab.cards => CollectionsText.noMyCards,
            EmployeeTab.receipts => CollectionsText.noMyReceipts,
            EmployeeTab.cash => CollectionsText.emptyCash,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionBar(
          key: const Key('collections-action-bar'),
          children: [
            if (widget.write)
              _BarButton(
                buttonKey: const Key('unlinked-collection'),
                label: CollectionsText.createStandalone,
                onPressed: online
                    ? () => showAppForm<void>(
                        context,
                        const UnlinkedReceiptForm(),
                      )
                    : null,
              ),
            if (widget.onPayroll != null)
              _BarButton(
                buttonKey: const Key('collections-payroll'),
                label: CollectionsText.payrollButton,
                onPressed: widget.onPayroll,
              ),
            CollectionsExportButton(
              data: data,
              admin: false,
              batchId: data.openBatches.firstOrNull?.id,
              label: CollectionsText.exportDay,
              icon: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Grid2(
          key: const Key('collections-metrics'),
          children: [
            _SummaryCard(
              key: const Key('metric-assigned'),
              title: CollectionsText.myCardsTitle,
              // 537 `assignedCount` (= the caller's active cards).
              value: '${data.assignedCount ?? data.assignments.length}',
              unit: CollectionsText.cardsUnit,
              edge: _amber(context),
            ),
            _SummaryCard(
              key: const Key('metric-pending'),
              title: CollectionsText.sumPending,
              // 537 metrics.pendingCount + metrics.unlinkedPendingCount.
              value:
                  '${(data.pendingCount ?? 0) + (data.unlinkedPendingCount ?? 0)}',
              unit: CollectionsText.operations,
              edge: look.violet,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _SummaryCard(
          key: const Key('metric-cash'),
          title: CollectionsText.cashToHand,
          // 537 metrics.cashOutstandingUnits: own approved, cash not
          // received, earlier batches and cancelled cards included.
          value: money.formatOrDash(data.cashOutstandingUnits, Currency.lyd),
          money: true,
          note: CollectionsText.cashToHandNote,
          edge: _amber(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          key: const Key('collections-tabs'),
          children: [
            for (final tab in EmployeeTab.values) ...[
              if (tab != EmployeeTab.values.first)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TabChip(
                  key: Key('collections-tab-${tab.name}'),
                  label: switch (tab) {
                    EmployeeTab.cards => CollectionsText.tabMyCards,
                    EmployeeTab.receipts => CollectionsText.tabMyReceipts,
                    EmployeeTab.cash => CollectionsText.tabMyCash,
                  },
                  selected: _tab == tab,
                  onTap: () => setState(() => _tab = tab),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _LabeledField(
          label: CollectionsText.searchNameOrPhone,
          child: TextField(
            key: const Key('collections-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: CollectionsText.searchNameOrPhoneHint,
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CollectionsText.employeeSearchNote,
          style: cairo(12, 500, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        _ListCard(
          key: const Key('collections-list'),
          title: title,
          pill: true,
          trailing: const _SyncStatus(),
          child: rows.isEmpty
              ? _EmptyLine(
                  key: const Key('collections-empty-assignments'),
                  text: empty,
                  large: true,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final assignment in rows.assignments)
                      _AssignmentCard(
                        assignment: assignment,
                        history: collectionCardHistory(data, assignment.id),
                        money: money,
                        admin: false,
                      ),
                    for (final submission in rows.submissions)
                      _ReceiptRow(submission: submission, money: money),
                    for (final receipt in rows.unlinked)
                      _EmployeeUnlinkedCard(receipt: receipt, money: money),
                    for (final item in rows.outstanding)
                      _OutstandingRow(item: item, money: money, cash: false),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One own receipt on «تحصيلاتي» / «النقدية»: customer, kind, amount and
/// the server status (pending / approved / rejected, then cash).
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.submission, required this.money});

  final CollectionSubmissionDto submission;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gloss = switch (submission.status) {
      'approved' => look.glossCredit,
      'rejected' => look.glossGrey,
      _ => look.glossViolet,
    };
    final state = switch (submission.status) {
      'pending' => CollectionsText.awaitingApproval,
      'approved' =>
        submission.cashReceivedAt != null
            ? CollectionsText.cashReceived
            : CollectionsText.waitingCashFromAdmin,
      _ => CollectionsText.rejected,
    };
    return Padding(
      key: Key('my-receipt-${submission.id}'),
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: _HistoryLine(
        gloss: gloss,
        title: [
          submission.customerName ?? '',
          submission.mode == 'full'
              ? CollectionsText.fullReceipt
              : CollectionsText.partialReceipt,
        ].where((s) => s.isNotEmpty).join(' — '),
        amount: money.formatOrDash(submission.amountUnits, Currency.lyd),
        trailing: submission.businessDate,
        status: _Badge(text: state, gloss: gloss, strong: true),
      ),
    );
  }
}

// --------------------------------------------------------------- layout

/// Two fields side by side, or stacked when the line is tight.
class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_tight(context, constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.sm),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: cairo(13, 700, color: context.look.ink)),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

/// The glossy bar of pill buttons (the website's green bar, in the app's
/// hero gloss). Buttons inside take the bar's colours.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gloss = look.glossHero;
    final radius = BorderRadius.circular(AppRadii.xl);
    final on = look.onHero;
    final pill = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.disabled) ? on.withValues(alpha: 0.5) : on,
      ),
      backgroundColor: WidgetStatePropertyAll(on.withValues(alpha: 0.12)),
      side: WidgetStatePropertyAll(
        BorderSide(color: on.withValues(alpha: 0.55)),
      ),
      textStyle: WidgetStatePropertyAll(cairo(13, 800)),
      iconColor: WidgetStatePropertyAll(on),
    );
    final theme = Theme.of(context);
    final barTheme = theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(style: pill),
      outlinedButtonTheme: OutlinedButtonThemeData(style: pill),
      textButtonTheme: TextButtonThemeData(style: pill),
      textTheme: theme.textTheme.apply(bodyColor: on, displayColor: on),
    );
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
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            child: Theme(
              data: barTheme,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: on),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow =
                        _tight(context, constraints.maxWidth) ||
                        constraints.maxWidth / children.length < 104;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final child in children) ...[
                            if (child != children.first)
                              const SizedBox(height: AppSpacing.xs),
                            child,
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final child in children) ...[
                          if (child != children.first)
                            const SizedBox(width: AppSpacing.xs),
                          Expanded(child: child),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      child: Text(label, maxLines: 2, textAlign: TextAlign.center),
    );
  }
}

/// «إغلاق ومسح الدفعة» for the chosen batch. 537 refuses an unsettled
/// batch (COLLECTION_DAY_NOT_SETTLED); that message is shown, never hidden.
class _CloseBatchButton extends ConsumerWidget {
  const _CloseBatchButton({required this.batch});

  final CollectionBatchDto? batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = this.batch;
    if (batch == null) {
      return const OutlinedButton(
        key: Key('close-batch'),
        onPressed: null,
        child: Text(CollectionsText.closeBatch, textAlign: TextAlign.center),
      );
    }
    return GuardedMutation(
      buttonKey: const Key('close-batch'),
      inputs: 'close:${batch.id}',
      label: CollectionsText.closeBatch,
      confirmText: CollectionsText.closeConfirm,
      destructive: true,
      onVersionConflict: () => ref.invalidate(collectionsProvider),
      onSubmit: (meta) async {
        try {
          await ref
              .read(apiLayerProvider)
              .collections
              .closeDay(batchId: batch.id, meta: meta);
        } on ConflictException catch (error) {
          ref.invalidate(collectionsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.message)));
          }
          return error.message;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(CollectionsText.batchClosed)),
          );
        }
        ref.invalidate(collectionsProvider);
        return null;
      },
    );
  }
}

/// Two equal columns (one when tight); each row's cells share a height.
class _Grid2 extends StatelessWidget {
  const _Grid2({required this.children, this.tight = false, super.key});

  final List<Widget> children;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final gap = tight ? AppSpacing.sm : AppSpacing.sm;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_tight(context, constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children) ...[
                if (child != children.first) SizedBox(height: gap),
                child,
              ],
            ],
          );
        }
        final lines = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          if (i > 0) lines.add(SizedBox(height: gap));
          lines.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  SizedBox(width: gap),
                  Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: lines,
        );
      },
    );
  }
}

/// A summary card with a coloured start edge, as in the pictures.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.edge,
    this.money = false,
    this.unit,
    this.note,
    super.key,
  });

  final String title;
  final String value;
  final Color edge;
  final bool money;
  final String? unit;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final radius = BorderRadius.circular(AppRadii.xl);
    final figure = context.textExtras.amount.copyWith(color: look.ink);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: radius,
        border: Border.all(color: look.cardBorder),
        boxShadow: look.glass
            ? null
            : const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: edge, width: 5)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: cairo(14, 800, color: look.ink)),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: money
                      ? MoneyText(value, style: figure)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value,
                              textDirection: TextDirection.ltr,
                              style: figure,
                            ),
                            if (unit != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                unit!,
                                style: cairo(13, 600, color: look.muted),
                              ),
                            ],
                          ],
                        ),
                ),
                if (note != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(note!, style: cairo(11, 500, color: look.muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab with an optional count; the chosen one wears the hero gloss.
class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.countKey,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gloss = look.glossHero;
    final radius = BorderRadius.circular(AppRadii.xl);
    final ink = selected ? look.onHero : look.ink;
    final body = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: cairo(13, 800, color: ink),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.xs),
            DecoratedBox(
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                child: Text(
                  '$count',
                  key: countKey,
                  textDirection: TextDirection.ltr,
                  style: cairo(12, 800, color: ink),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: selected
              ? DecoratedBox(
                  decoration: gloss
                      .decoration(radius)
                      .copyWith(boxShadow: gloss.glowShadow),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: GlossSheen(
                      gloss: gloss,
                      radius: radius,
                      child: body,
                    ),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: look.card,
                    borderRadius: radius,
                    border: Border.all(color: look.cardBorder),
                  ),
                  child: body,
                ),
        ),
      ),
    );
  }
}

/// The chosen tab's list, under its title (a gloss pill for the employee).
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.child,
    this.trailing,
    this.pill = false,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gloss = look.glossHero;
    final radius = BorderRadius.circular(AppRadii.pill);
    final heading = pill
        ? DecoratedBox(
            decoration: gloss.decoration(radius),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(title, style: cairo(16, 800, color: look.onHero)),
            ),
          )
        : Text(title, style: cairo(18, 800, color: look.ink));
    return CollectionsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [heading, ?trailing],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// The app polls `/api/events` while online and signed in, so «live» here
/// is the connection the realtime refresh runs on.
class _SyncStatus extends ConsumerWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider);
    final look = context.look;
    return Row(
      key: const Key('collections-sync-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: online ? look.success : look.danger),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            online ? CollectionsText.liveSync : CollectionsText.offlineSync,
            style: cairo(12, 500, color: look.muted),
          ),
        ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text, this.large = false, super.key});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        style: cairo(large ? 18 : 14, 600, color: context.look.muted),
      ),
    );
  }
}

String _money(MoneyFormatter money, int units) =>
    money.formatOrDash(MoneyValue.known(units), Currency.lyd);

/// The pictures' gold, as an amber that reads on both themes.
Color _amber(BuildContext context) =>
    context.look.glass ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

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

/// One column when the line is narrow or the text scale would clip a pair.
bool _tight(BuildContext context, double maxWidth) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return !maxWidth.isFinite || scale >= 1.3 || maxWidth < 320;
}
