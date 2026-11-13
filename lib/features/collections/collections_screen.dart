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
/// Admin (`collections.decide`): batch and employee filters side by side,
/// one row of payroll / close / statement, the batch close note, four
/// summary cards, search beside the employee-totals menu, four existing
/// status tabs, then the list. Employee (no `collections.decide`): the same
/// density for their own actions, own counts, own tabs and own list. No
/// batch filter, close, or staff totals. Payroll opens from the bar.
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

    return RefreshIndicator(
      key: const Key('collections-refresh'),
      onRefresh: () async {
        ref.invalidate(collectionsProvider);
        ref.invalidate(payrollProvider);
        await ref.read(collectionsProvider.future);
      },
      child: ListView(
        key: CollectionsScreen.screenKey,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding(width).copyWith(bottom: AppSpacing.xxl),
        children: [
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
      ),
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
    // The server allows every admin role. It does not check a close-day code.
    final close = permissions.isAdminRole;
    final look = context.look;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionsPanel(
          key: const Key('collections-filter-card'),
          child: _PeerRow(
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
        ),
        const SizedBox(height: AppSpacing.sm),
        _ActionBar(
          key: const Key('collections-action-bar'),
          oneRow: true,
          tones: [
            if (widget.onPayroll != null) const Color(0xFF178447),
            if (close) const Color(0xFFB52835),
            const Color(0xFF178447),
          ],
          children: [
            if (widget.onPayroll != null)
              _BarButton(
                buttonKey: const Key('collections-payroll'),
                label: CollectionsText.payrollButton,
                onPressed: widget.onPayroll,
              ),
            if (close)
              _CloseBatchButton(
                batch: batch,
                settlement: settlement,
                label: CollectionsText.closeShort,
              ),
            CollectionsExportButton(
              data: data,
              admin: true,
              batchId: batch?.id,
              label: CollectionsText.exportShort,
              icon: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.sm),
        _NumberRow(
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
              edge: look.violet,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _PeerRow(
          first: TextField(
            key: const Key('collections-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: CollectionsText.searchViewHint,
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          second: _EmployeeTotalsMenu(rows: data.employeeTotals, money: money),
        ),
        const SizedBox(height: AppSpacing.sm),
        _NumberRow(
          key: const Key('collections-tabs'),
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
      ],
    );
  }
}

class _EmployeeTotalsMenu extends StatefulWidget {
  const _EmployeeTotalsMenu({required this.rows, required this.money});

  final List<EmployeeTotalDto> rows;
  final MoneyFormatter money;

  @override
  State<_EmployeeTotalsMenu> createState() => _EmployeeTotalsMenuState();
}

class _EmployeeTotalsMenuState extends State<_EmployeeTotalsMenu> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('employee-totals-toggle'),
          onPressed: widget.rows.isEmpty
              ? null
              : () => setState(() => _open = !_open),
          child: Text(
            CollectionsText.employeeTotals,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: cairo(12, 800, color: look.ink),
          ),
        ),
        if (_open && widget.rows.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _EmployeeTotals(rows: widget.rows, money: widget.money),
        ],
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

/// Two compact cards on a phone, three when the row is wide.
Widget _assignmentGrid(List<Widget> cards) {
  if (cards.isEmpty) return const SizedBox.shrink();
  return LayoutBuilder(
    builder: (context, constraints) {
      final cols = constraints.maxWidth < 560
          ? 1
          : constraints.maxWidth >= 720
          ? 3
          : 2;
      const gap = 8.0;
      final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
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
        _assignmentGrid([
          for (final assignment in rows.assignments)
            _AssignmentCard(
              assignment: assignment,
              history: collectionCardHistory(data, assignment.id),
              money: money,
              admin: true,
            ),
        ]),
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
          oneRow: true,
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
              label: CollectionsText.exportShort,
              icon: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _NumberRow(
          key: const Key('collections-metrics'),
          children: [
            _SummaryCard(
              key: const Key('metric-assigned'),
              title: CollectionsText.assigned,
              // 537 `assignedCount` (= the caller's active cards).
              value: '${data.assignedCount ?? data.assignments.length}',
              edge: _amber(context),
            ),
            _SummaryCard(
              key: const Key('metric-pending'),
              title: CollectionsText.sumPending,
              // 537 metrics.pendingCount + metrics.unlinkedPendingCount.
              value:
                  '${(data.pendingCount ?? 0) + (data.unlinkedPendingCount ?? 0)}',
              edge: look.violet,
            ),
            _SummaryCard(
              key: const Key('metric-cash'),
              title: CollectionsText.cashOutstanding,
              // 537 metrics.cashOutstandingUnits: own approved, cash not
              // received, earlier batches and cancelled cards included.
              value: money.formatOrDash(
                data.cashOutstandingUnits,
                Currency.lyd,
              ),
              money: true,
              edge: _amber(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          CollectionsText.cashToHandNote,
          style: cairo(11, 500, color: look.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        _NumberRow(
          key: const Key('collections-tabs'),
          children: [
            for (final tab in EmployeeTab.values)
              _TabChip(
                key: Key('collections-tab-${tab.name}'),
                label: switch (tab) {
                  EmployeeTab.cards => CollectionsText.tabMyCards,
                  EmployeeTab.receipts => CollectionsText.tabMyReceipts,
                  EmployeeTab.cash => CollectionsText.tabMyCash,
                },
                selected: _tab == tab,
                onTap: () => setState(() => _tab = tab),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _LabeledField(
          label: CollectionsText.searchNameOrPhone,
          child: TextField(
            key: const Key('collections-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: CollectionsText.searchNameOrPhoneHint,
              prefixIcon: Icon(Icons.search),
              isDense: true,
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
                    _assignmentGrid([
                      for (final assignment in rows.assignments)
                        _AssignmentCard(
                          assignment: assignment,
                          history: collectionCardHistory(data, assignment.id),
                          money: money,
                          admin: false,
                        ),
                    ]),
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

/// Two peers that stay side by side, including at text scale 1.3.
class _PeerRow extends StatelessWidget {
  const _PeerRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: second),
      ],
    );
  }
}

/// Equal cells in one horizontal row. Content scales down instead of clipping.
class _NumberRow extends StatelessWidget {
  const _NumberRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: children[i]),
          ],
        ],
      ),
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
  const _ActionBar({
    required this.children,
    this.oneRow = false,
    this.tones,
    super.key,
  });

  final List<Widget> children;
  final bool oneRow;

  /// When set, each button is a solid colour instead of the hero bar.
  final List<Color>? tones;

  @override
  Widget build(BuildContext context) {
    final tones = this.tones;
    if (tones != null && tones.length == children.length) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _solidButton(context, tones[i], children[i])),
          ],
        ],
      );
    }
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
                        !oneRow &&
                        (_tight(context, constraints.maxWidth) ||
                            constraints.maxWidth / children.length < 104);
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

Widget _solidButton(BuildContext context, Color background, Widget child) {
  final style = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    backgroundColor: WidgetStatePropertyAll(background),
    foregroundColor: const WidgetStatePropertyAll(Colors.white),
    iconColor: const WidgetStatePropertyAll(Colors.white),
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textStyle: WidgetStatePropertyAll(cairo(11, 800)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
  );
  return Theme(
    data: Theme.of(context).copyWith(
      outlinedButtonTheme: OutlinedButtonThemeData(style: style),
      filledButtonTheme: FilledButtonThemeData(style: style),
    ),
    child: child,
  );
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
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// «الإغلاق» opens the website's confirm dialog, then
/// `POST /api/collections/days/close`. The next overview is the server's.
class _CloseBatchButton extends ConsumerWidget {
  const _CloseBatchButton({
    required this.batch,
    required this.settlement,
    this.label = CollectionsText.closeBatch,
  });

  final CollectionBatchDto? batch;
  final BatchSettlement settlement;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = this.batch;
    if (batch == null) {
      return OutlinedButton(
        key: const Key('close-batch'),
        onPressed: null,
        child: Text(label, textAlign: TextAlign.center),
      );
    }
    final pending = batch.pendingCount ?? settlement.reviewCount;
    final cashCount = batch.cashPendingCount ?? 0;
    final cashUnits = batch.cashPendingUnits ?? settlement.cashUnits;
    return FilledButton(
      key: const Key('close-batch'),
      onPressed: () {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _CloseBatchDialog(
            batchId: batch.id,
            pendingCount: pending,
            cashPendingCount: cashCount,
            cashPendingUnits: cashUnits,
          ),
        );
      },
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CloseBatchDialog extends ConsumerStatefulWidget {
  const _CloseBatchDialog({
    required this.batchId,
    required this.pendingCount,
    required this.cashPendingCount,
    required this.cashPendingUnits,
  });

  final String batchId;
  final int pendingCount;
  final int cashPendingCount;
  final int cashPendingUnits;

  @override
  ConsumerState<_CloseBatchDialog> createState() => _CloseBatchDialogState();
}

class _CloseBatchDialogState extends ConsumerState<_CloseBatchDialog> {
  var _exception = false;
  var _busy = false;
  var _changed = false;
  String? _error;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _outstanding =>
      widget.cashPendingCount > 0 || widget.cashPendingUnits > 0;

  bool get _canConfirm {
    if (_busy || widget.pendingCount > 0 || _changed) return false;
    if (!_outstanding) return true;
    return _exception && _reason.text.trim().length >= 5;
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .collections
          .closeDay(
            batchId: widget.batchId,
            meta: MutationMeta(),
            allowOutstandingCash: _exception,
            reason: _exception ? _reason.text.trim() : null,
            expectedCashPendingCount: _exception
                ? widget.cashPendingCount
                : null,
            expectedCashPendingUnits: _exception
                ? widget.cashPendingUnits
                : null,
          );
      ref.invalidate(collectionsProvider);
      if (!mounted) return;
      if (ack.raw['closed'] == false) {
        setState(() {
          _busy = false;
          _error = failureText(
            ref.read(errorHandlerProvider).toFailure(StateError('${ack.raw}')),
          );
        });
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      ref.invalidate(collectionsProvider);
      if (!mounted) return;
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      final changed = failure.code == 'COLLECTION_CASH_CHANGED';
      setState(() {
        _busy = false;
        _changed = changed;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(apiLayerProvider).money;
    return AlertDialog(
      title: const Text(CollectionsText.closeDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _outstanding
                  ? CollectionsText.closeOutstandingIntro
                  : CollectionsText.closeConfirm,
            ),
            if (widget.pendingCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                CollectionsText.closePendingAlert,
                key: const Key('close-batch-pending'),
              ),
            ],
            if (_outstanding) ...[
              const SizedBox(height: 8),
              Text(
                'نقدية غير مستلمة: ${money.format(widget.cashPendingUnits, Currency.lyd)} — ${widget.cashPendingCount} استلام',
                key: const Key('close-batch-outstanding'),
              ),
              CheckboxListTile(
                key: const Key('close-batch-exception'),
                contentPadding: EdgeInsets.zero,
                value: _exception,
                onChanged: _busy || widget.pendingCount > 0
                    ? null
                    : (value) => setState(() {
                        _exception = value ?? false;
                        _changed = false;
                        _error = null;
                      }),
                title: const Text(CollectionsText.closeException),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_exception) ...[
                const Text(CollectionsText.closeExceptionNote),
                TextField(
                  key: const Key('close-batch-reason'),
                  controller: _reason,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 3,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: CollectionsText.closeExceptionReason,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_changed)
                const Text(
                  CollectionsText.closeCashChanged,
                  key: Key('close-batch-changed'),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('close-batch-error')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text(CollectionsText.closeNo),
        ),
        FilledButton(
          key: const Key('confirm-close-batch'),
          onPressed: _canConfirm ? _send : null,
          child: Text(
            _exception
                ? CollectionsText.closeYesException
                : CollectionsText.closeYes,
          ),
        ),
      ],
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
    super.key,
  });

  final String title;
  final String value;
  final Color edge;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final radius = BorderRadius.circular(12);
    final figure = context.textExtras.amount.copyWith(color: look.ink);
    final tile = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2230)
        : const Color(0xFFFFFFFF);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tile,
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
            border: BorderDirectional(start: BorderSide(color: edge, width: 6)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: cairo(11, 700, color: look.ink),
                  ),
                  const SizedBox(height: 2),
                  money
                      ? MoneyText(value, style: figure.copyWith(fontSize: 15))
                      : Text(
                          value,
                          textDirection: TextDirection.ltr,
                          style: figure.copyWith(fontSize: 15),
                        ),
                ],
              ),
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
    final radius = BorderRadius.circular(AppRadii.xl);
    final ink = selected ? const Color(0xFF211600) : look.ink;
    final body = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 4,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: cairo(11, 800, color: ink),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7AE12),
                    borderRadius: radius,
                  ),
                  child: body,
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
    final balanceText = money.formatOrDash(
      assignment.balanceUnits,
      Currency.lyd,
    );
    final assignedText = assignment.assignedBalanceUnits == null
        ? 'غير مسجلة'
        : money.formatOrDash(assignment.assignedBalanceUnits, Currency.lyd);
    Widget pair(String label, String value, {Key? key}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: cairo(9, 700, color: gloss.ink.withValues(alpha: 0.8)),
            ),
            Text(
              value,
              key: key,
              style: cairo(14, 800, color: gloss.amount),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      key: Key('assignment-${assignment.id}'),
      decoration: BoxDecoration(
        gradient: gloss.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gloss.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0xE6E7AE12),
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox.shrink(
              key: Key('tone-${assignment.id}-${collectionToneName(tone)}'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          assignment.customerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: cairo(13, 800, color: gloss.ink),
                        ),
                      ),
                      if ((assignment.assigneeName ?? '').isNotEmpty)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(start: 6),
                            child: Text(
                              assignment.assigneeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cairo(10, 600, color: gloss.ink),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      pair(
                        'قيمة التوجيه',
                        assignedText,
                        key: Key('assigned-amount-${assignment.id}'),
                      ),
                      pair(
                        'الرصيد الحالي',
                        balanceText,
                        key: Key('assignment-balance-${assignment.id}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _collectionStateLabel(assignment),
                          key: Key('assignment-state-${assignment.id}'),
                          style: cairo(10, 800, color: gloss.ink),
                        ),
                      ),
                      if (history.isNotEmpty ||
                          assignment.cashOutstandingCount > 0)
                        Text(
                          '${history.isNotEmpty ? history.length : assignment.cashOutstandingCount} استلام',
                          style: cairo(10, 800, color: gloss.ink),
                        ),
                    ],
                  ),
                  if (!admin)
                    LtrText(
                      assignment.phone ?? CollectionsText.noPhone,
                      key: Key('phone-${assignment.id}'),
                      style: cairo(10, 600, color: gloss.ink),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x66FFFFFF)),
            Material(
              color: Colors.transparent,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: _ReceiptFold(
                  initiallyExpanded:
                      !admin ||
                      history.any(
                        (item) => item.status == 'pending' || item.awaitingCash,
                      ),
                  ink: gloss.ink,
                  children: [
                    if (history.isEmpty && admin)
                      Text(
                        CollectionsText.noHistory,
                        style: cairo(11, 600, color: gloss.ink),
                      ),
                    for (final item in history)
                      _SubmissionLine(
                        assignment: assignment,
                        submission: item,
                        money: money,
                        admin: admin,
                      ),
                    if (!admin)
                      _EmployeeActions(assignment: assignment, money: money),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 5,
              child: ColoredBox(color: Color(0xFFE7AE12)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The words on a website collection card, from fields the server already
/// sends. No status is invented.
String _collectionStateLabel(CollectionAssignmentDto card) {
  if (card.latestStatus == 'rejected' && !card.hasPending) {
    return 'رُفضت العملية — التوجيه مستمر';
  }
  if (card.hasPending) return 'يحتاج مراجعة';
  if (card.cashOutstandingCount > 0) return 'نقدية لم تُسلّم';
  if (card.latestCashReceivedAt != null) return 'تم تسليم النقدية';
  return 'جاهز للمتابعة';
}

/// «تفاصيل الاستلامات»: ◂ while closed, ▾ while open, on the right of the words.
class _ReceiptFold extends StatefulWidget {
  const _ReceiptFold({
    required this.initiallyExpanded,
    required this.ink,
    required this.children,
  });

  final bool initiallyExpanded;
  final Color ink;
  final List<Widget> children;

  @override
  State<_ReceiptFold> createState() => _ReceiptFoldState();
}

class _ReceiptFoldState extends State<_ReceiptFold> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: widget.initiallyExpanded,
      onExpansionChanged: (open) => setState(() => _open = open),
      showTrailingIcon: false,
      minTileHeight: 34,
      visualDensity: VisualDensity.compact,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _open ? Icons.keyboard_arrow_down : Icons.chevron_left,
            size: 18,
            color: widget.ink,
            textDirection: TextDirection.ltr,
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'تفاصيل الاستلامات',
                style: cairo(11, 800, color: widget.ink),
              ),
            ),
          ),
        ],
      ),
      children: widget.children,
    );
  }
}

class _SubmissionLine extends ConsumerWidget {
  const _SubmissionLine({
    required this.assignment,
    required this.submission,
    required this.money,
    required this.admin,
  });

  final CollectionAssignmentDto assignment;
  final CollectionSubmissionDto submission;
  final MoneyFormatter money;
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
    final transactionId = (submission.approvedTransactionId ?? '').trim();
    final cancel =
        admin &&
        permissions.isAdminRole &&
        awaiting &&
        transactionId.isNotEmpty &&
        !submission.currencyMismatch;
    final received = submission.cashReceivedAt != null;
    final formatted = money.formatOrDash(submission.amountUnits, Currency.lyd);
    final name = (submission.customerName ?? '').trim().isEmpty
        ? assignment.customerName
        : submission.customerName!.trim();
    final who = (submission.submittedByName ?? '').trim();
    final kind = submission.mode == 'full'
        ? CollectionsText.fullReceipt
        : CollectionsText.partialReceipt;
    final stamp = _receiptStamp(submission.createdAt);
    const ink = Color(0xFF211600);
    const muted = Color(0xFF78716C);
    Widget pill(Color fill, Color ink, Color edge, Widget child) {
      return _pillAction(fill, ink, edge, child);
    }

    final actions = <Widget>[
      if (decide && pending) ...[
        pill(
          const Color(0xFFE4F3E9),
          const Color(0xFF145535),
          const Color(0xFFABCAB7),
          GuardedMutation(
            buttonKey: Key('approve-${submission.id}'),
            inputs: 'approve:${submission.id}',
            label: AppStrings.approve,
            onVersionConflict: () => ref.invalidate(collectionsProvider),
            onSubmit: (meta) => _decide(ref, CollectionDecision.approve, meta),
          ),
        ),
        const SizedBox(width: 6),
        pill(
          const Color(0xFFFBE8E7),
          const Color(0xFF8F2831),
          const Color(0xFFDFB3B7),
          GuardedMutation(
            buttonKey: Key('reject-${submission.id}'),
            inputs: 'reject:${submission.id}',
            label: AppStrings.reject,
            onVersionConflict: () => ref.invalidate(collectionsProvider),
            onSubmit: (meta) => _decide(ref, CollectionDecision.reject, meta),
          ),
        ),
      ],
      if (cash && awaiting)
        pill(
          const Color(0xFFE4F3E9),
          const Color(0xFF145535),
          const Color(0xFFABCAB7),
          GuardedMutation(
            buttonKey: Key('cash-${submission.id}'),
            inputs: 'cash:${submission.id}',
            label: CollectionsText.confirmCash,
            reportErrorInline: false,
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
        ),
      if (cash && awaiting && cancel) const SizedBox(width: 6),
      if (cancel)
        pill(
          const Color(0xFFFBE8E7),
          const Color(0xFF8F2831),
          const Color(0xFFDFB3B7),
          FilledButton(
            key: Key('cancel-approval-${submission.id}'),
            onPressed: () => _cancelApproval(context, ref, transactionId),
            child: const Text(CollectionsText.cancelApproval),
          ),
        ),
    ];
    return Padding(
      key: Key('submission-${submission.id}'),
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(
                color: Color(0xFFE7AE12),
                child: SizedBox(height: 3, width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: cairo(13, 800, color: ink),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _lydFigure(formatted),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      who.isEmpty ? kind : '$who · $kind',
                      style: cairo(10, 600, color: muted),
                    ),
                    if (stamp.isNotEmpty)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            stamp,
                            style: cairo(10, 600, color: muted),
                          ),
                        ),
                      ),
                    if (awaiting)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _AwaitingCash(
                          id: submission.id,
                          text: admin
                              ? CollectionsText.awaitingCash
                              : CollectionsText.waitingCashFromAdmin,
                        ),
                      ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
                          ),
                        ),
                      ),
                    ] else if (received || submission.status == 'rejected')
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _neutralPill(
                          submission.status == 'rejected'
                              ? CollectionsText.rejected
                              : CollectionsText.cashReceived,
                          key: received
                              ? Key('cash-done-${submission.id}')
                              : null,
                        ),
                      )
                    else if (pending)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _neutralPill(CollectionsText.awaitingApproval),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _cancelApproval(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CancelApprovalDialog(
        name: (submission.customerName ?? '').trim().isEmpty
            ? assignment.customerName
            : submission.customerName!.trim(),
        amount: money.formatOrDash(submission.amountUnits, Currency.lyd),
      ),
    );
    if (reason == null || !context.mounted) return;
    final meta = MutationMeta();
    try {
      await ref
          .read(apiLayerProvider)
          .collections
          .cancelApproval(
            submission.id,
            reason: reason,
            expectedTransactionId: transactionId,
            meta: meta,
          );
      ref.invalidate(collectionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureText(failure))));
    }
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

    return Row(
      children: [
        Expanded(
          child: blocked
              ? _whiteAction(
                  key: Key('full-${assignment.id}'),
                  label: CollectionsText.fullReceipt,
                  onPressed: null,
                )
              : _siteAction(
                  const Color(0xFFFFFFFF),
                  const Color(0xFF174D43),
                  GuardedMutation(
                    buttonKey: Key('full-${assignment.id}'),
                    inputs: 'full:${assignment.id}:$balance',
                    label: CollectionsText.fullReceipt,
                    confirmText: CollectionsText.fullConfirm(
                      money.formatOrDash(assignment.balanceUnits, Currency.lyd),
                    ),
                    onVersionConflict: () =>
                        ref.invalidate(collectionsProvider),
                    // 537f073 expects the current debt with a full receipt and
                    // refuses it if the debt changed (FULL_AMOUNT_CHANGED).
                    onSubmit: (_) => _send(context, ref, 'full', balance),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _whiteAction(
            key: Key('submit-${assignment.id}'),
            label: CollectionsText.partialReceipt,
            onPressed: blocked || !online
                ? null
                : () => showAppForm<void>(
                    context,
                    PartialReceiptForm(assignment: assignment),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _whiteAction(
            key: Key('call-${assignment.id}'),
            label: CollectionsText.call,
            icon: Icons.phone_outlined,
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
          ),
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

/// White (or solid) action on a coloured collection card, matching the
/// website's `.collection-card button` so the label stays readable.
Widget _siteAction(Color background, Color foreground, Widget child) {
  return Theme(
    data: ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.55),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          textStyle: cairo(11, 800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    child: child,
  );
}

Widget _whiteAction({
  required Key key,
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
}) {
  return FilledButton(
    key: key,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFFFFFFF),
      foregroundColor: const Color(0xFF174D43),
      disabledBackgroundColor: const Color(0xFFE7E5E4),
      disabledForegroundColor: const Color(0xFF174D43).withValues(alpha: 0.45),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: cairo(11, 800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: onPressed,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 3)],
          Text(label),
        ],
      ),
    ),
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.name,
    required this.amount,
    required this.gloss,
    this.subtitle,
  });

  final String name;
  final String? subtitle;
  final String amount;
  final Gloss gloss;

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
  });

  final Gloss gloss;
  final String title;
  final String? amount;
  final String? trailing;
  final Widget? status;

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
          ],
        ),
      ),
    );
  }
}

class _AwaitingCash extends StatelessWidget {
  const _AwaitingCash({
    required this.id,
    this.gloss,
    this.text = CollectionsText.awaitingCash,
  });

  final String id;
  final Gloss? gloss;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (gloss == null) {
      return Padding(
        key: ValueKey('awaiting-cash-$id'),
        padding: EdgeInsets.zero,
        child: Text(
          text,
          style: cairo(10, 600, color: const Color(0xFF78716C)),
        ),
      );
    }
    return _Badge(
      key: ValueKey('awaiting-cash-$id'),
      text: text,
      gloss: gloss!,
      strong: true,
    );
  }
}

/// Amount with a smaller «د.ل», kept LTR so the unit stays on the number.
Widget _lydFigure(String formatted) {
  final cut = formatted.lastIndexOf(' ');
  final number = cut < 0 ? formatted : formatted.substring(0, cut);
  final unit = cut < 0 ? '' : formatted.substring(cut);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: number,
            style: cairo(16, 800, color: const Color(0xFF211600)),
          ),
          TextSpan(
            text: unit,
            style: cairo(10, 700, color: const Color(0xFF211600)),
          ),
        ],
      ),
    ),
  );
}

/// Light fill, dark label, stadium shape. The action itself is unchanged.
Widget _pillAction(Color fill, Color ink, Color edge, Widget child) {
  return Theme(
    data: ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: ink,
          disabledBackgroundColor: fill.withValues(alpha: 0.55),
          disabledForegroundColor: ink.withValues(alpha: 0.7),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          textStyle: cairo(11, 800),
          shape: const StadiumBorder(),
          side: BorderSide(color: edge),
        ),
      ),
    ),
    child: child,
  );
}

Widget _neutralPill(String text, {Key? key}) {
  return DecoratedBox(
    key: key,
    decoration: BoxDecoration(
      color: const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE7E5E4)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(text, style: cairo(10, 700, color: const Color(0xFF44403C))),
    ),
  );
}

/// The website's cancel dialog: reason of 5–500 characters, then the POST.
class _CancelApprovalDialog extends StatefulWidget {
  const _CancelApprovalDialog({required this.name, required this.amount});

  final String name;
  final String amount;

  @override
  State<_CancelApprovalDialog> createState() => _CancelApprovalDialogState();
}

class _CancelApprovalDialogState extends State<_CancelApprovalDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _reason.text.trim().length >= 5;
    return AlertDialog(
      title: const Text(CollectionsText.cancelApprovalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.name} — ${widget.amount}'),
          const SizedBox(height: 8),
          const Text(CollectionsText.cancelApprovalBody),
          const SizedBox(height: 8),
          TextField(
            key: const Key('cancel-approval-reason'),
            controller: _reason,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: CollectionsText.cancelApprovalReason,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.back),
        ),
        FilledButton(
          key: const Key('confirm-cancel-approval'),
          onPressed: ready
              ? () => Navigator.pop(context, _reason.text.trim())
              : null,
          child: const Text(CollectionsText.cancelApprovalConfirm),
        ),
      ],
    );
  }
}

/// `2026/11/10، 3:43 م` from the receipt's own timestamp.
String _receiptStamp(DateTime? at) {
  if (at == null) return '';
  final local = at.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour;
  final clock = hour % 12 == 0 ? 12 : hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final mark = hour < 12 ? 'ص' : 'م';
  return '${local.year}/$month/$day، $clock:$minute $mark';
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
