import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../performance/history_window.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/section_kit.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
import 'company_card_tone.dart';
import 'customer_card_tone.dart';
import 'edit_account_card_screen.dart';
import 'ledger_running_balance.dart';
import 'overpayment_warning.dart';
import 'transaction_correction_form.dart';

/// A write may send [expectedVersion] only from a settled card. Loading,
/// refresh, and error (including a failed reload) keep the previous figure
/// on screen, and [AsyncValue.asData] is either null or still the old card.
bool _cardReadyForWrite(AsyncValue<AccountCardDto> card) {
  if (card.isLoading || card.hasError) return false;
  return card.asData?.value.version != null;
}

/// Ledger for one card. Customers, companies, Libyan deposits, and Egyptian
/// deposits all use this screen; [section] selects the repository and the labels.
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({required this.section, required this.id, super.key});

  final AccountSection section;
  final String id;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  /// True from a successful movement until [accountCardProvider] returns
  /// the reload. While this is set, the header does not use the card that
  /// was on screen before the payment.
  bool _balanceAwaitingReload = false;

  /// [MutationAck.balanceUnits] for that movement. Null and invalid stay
  /// as they arrived.
  MoneyValue? _ackBalance;

  /// The row whose correction form is open in place, if any.
  String? _editingId;

  /// The page the screen last opened at the entry buttons for.
  String? _openedAtBottomFor;

  /// Older pages fetched automatically behind the newest page, newest
  /// first, so row 1 is the first movement (Ali, 2026-11-03). Same GET
  /// endpoint with `before`; display only.
  final _olderPages = <LedgerPage>[];
  String? _olderFor;
  String? _olderCursor;
  String? _olderError;
  var _olderBusy = false;

  /// A safety stop for very long records; the rest loads on request.
  static const _autoPageLimit = 200;

  final _rows = ScrollController();
  final _innerRows = ScrollController();
  final _columnsScroll = ScrollController();
  final _headerScroll = ScrollController();
  var _syncingColumns = false;
  var _showJumpTop = false;
  var _showJumpBottom = false;

  @override
  void initState() {
    super.initState();
    _columnsScroll.addListener(
      () => _syncColumns(_columnsScroll, _headerScroll),
    );
    _headerScroll.addListener(
      () => _syncColumns(_headerScroll, _columnsScroll),
    );
    _rows.addListener(_updateJumpButtons);
    _innerRows.addListener(_updateJumpButtons);
  }

  /// The sticky names and the rows scroll sideways as one table.
  void _syncColumns(ScrollController from, ScrollController to) {
    if (_syncingColumns || !from.hasClients || !to.hasClients) return;
    final position = to.position;
    final target = from.offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((to.offset - target).abs() < 0.5) return;
    _syncingColumns = true;
    to.jumpTo(target);
    _syncingColumns = false;
  }

  /// The table opens at its start (التسلسل, then the date in RTL), even
  /// after focusing القيمة scrolled it sideways.
  void _toTableStart([int frames = 12]) {
    if (!mounted) return;
    for (final c in [_columnsScroll, _headerScroll]) {
      if (c.hasClients && c.offset != c.position.minScrollExtent) {
        c.jumpTo(c.position.minScrollExtent);
      }
    }
    if (frames > 0) {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _toTableStart(frames - 1))
        ..scheduleFrame();
    }
  }

  static bool _atTop(ScrollController controller) =>
      !controller.hasClients || controller.position.pixels <= 8;

  /// Small up/down buttons once the user is away from either end.
  void _updateJumpButtons() {
    if (!mounted) return;
    final top = !(_atTop(_rows) && _atTop(_innerRows));
    final bottom = !(_atBottom(_rows) && _atBottom(_innerRows));
    if (top == _showJumpTop && bottom == _showJumpBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showJumpTop = top;
        _showJumpBottom = bottom;
      });
    });
  }

  void _jumpToTop() {
    if (_innerRows.hasClients) _innerRows.jumpTo(0);
    if (_rows.hasClients) _rows.jumpTo(0);
  }

  AccountSection get section => widget.section;
  String get id => widget.id;

  @override
  void dispose() {
    _rows.dispose();
    _innerRows.dispose();
    _columnsScroll.dispose();
    _headerScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section || oldWidget.id != widget.id) {
      _balanceAwaitingReload = false;
      _ackBalance = null;
      _editingId = null;
      _openedAtBottomFor = null;
      _olderFor = null;
      _olderPages.clear();
    }
  }

  static bool _atBottom(ScrollController controller) {
    if (!controller.hasClients) return true;
    final position = controller.position;
    return position.pixels >= position.maxScrollExtent - 4;
  }

  /// Starts (or restarts, after a reload) fetching every older page.
  void _syncOlder(String key, LedgerPage page) {
    if (_olderFor == key) return;
    _olderFor = key;
    _olderPages.clear();
    _olderCursor = page.page.nextCursor;
    _olderError = null;
    _olderBusy = false;
    if (_olderCursor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOlder(key));
    }
  }

  Future<void> _loadOlder(String key, {bool manual = false}) async {
    if (!mounted || _olderFor != key || _olderBusy) return;
    final cursor = _olderCursor;
    if (cursor == null) return;
    if (!manual && _olderPages.length >= _autoPageLimit) return;
    setState(() {
      _olderBusy = true;
      _olderError = null;
    });
    try {
      final older = await ref
          .read(apiLayerProvider)
          .accounts
          .ledger(section, id, before: cursor);
      if (!mounted || _olderFor != key) return;
      final atBottom = _atBottom(_rows) && _atBottom(_innerRows);
      if (atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEntry());
      }
      setState(() {
        _olderPages.add(older);
        _olderCursor = older.page.nextCursor;
        _olderBusy = false;
      });
      if (_olderCursor != null) unawaited(_loadOlder(key));
    } catch (error) {
      if (!mounted || _olderFor != key) return;
      setState(() {
        _olderBusy = false;
        _olderError = failureText(
          ref.read(errorHandlerProvider).toFailure(error),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountCardProvider((section, id)), (previous, next) {
      if (!_balanceAwaitingReload) return;
      // A failed reload keeps [MutationAck.balanceUnits]. The header does
      // not go back to the card that was on screen before the payment.
      if (next.isLoading || next.isRefreshing || next.hasError) return;
      if (!next.hasValue) return;
      setState(() {
        _balanceAwaitingReload = false;
        _ackBalance = null;
      });
    });
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(section.sectionKey)) return const ForbiddenPane();
    final ledger = ref.watch(ledgerProvider((section, id)));
    final card = ref.watch(accountCardProvider((section, id)));
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    String messageOf(Object error) =>
        failureText(ref.read(errorHandlerProvider).toFailure(error));
    failureOf(Object error) => ref.read(errorHandlerProvider).toFailure(error);
    final reloadError = _balanceAwaitingReload && card.hasError
        ? messageOf(card.error!)
        : null;

    return Scaffold(
      key: Key('screen-ledger-${section.path}'),
      body: KeptData<AccountCardDto>(
        value: card,
        resetKey: '${section.path}/$id',
        expand: true,
        onRetry: () {
          ref.invalidate(accountCardProvider((section, id)));
          ref.invalidate(ledgerProvider((section, id)));
        },
        messageOf: messageOf,
        failureOf: failureOf,
        loading: const _LedgerLoading(),
        builder: (loadedCard) {
          // Writes stay hidden until the card has loaded and is not system-managed.
          final canWrite =
              !loadedCard.systemManaged &&
              permissions.canWrite(section.sectionKey);
          final padding = pagePadding(MediaQuery.sizeOf(context).width);
          // The total card stays on top while the table scrolls (Ali,
          // 2026-11-03).
          // Customers and companies share the total card design; each
          // section reads its own balance rule (Ali, 2026-11-03).
          final glossyTotal =
              section == AccountSection.customers ||
              section == AccountSection.companies;
          // Top: the owner's name in a pill, then small round buttons
          // (jump, تعديل البيانات, ×). Nothing else above the table.
          final bar = Padding(
            padding: padding.copyWith(top: 0, bottom: 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _OwnerPill(
                      name: loadedCard.name,
                      section: _ledgerTitle(section),
                    ),
                  ),
                ),
                // In the bar, so they never cover a row (Ali, 2026-11-03).
                _JumpButtons(
                  showTop: _showJumpTop,
                  showBottom: _showJumpBottom,
                  onTop: _jumpToTop,
                  onBottom: _jumpToEntry,
                ),
                _RoundAction(
                  child: EditAccountCardButton(
                    section: section,
                    card: loadedCard,
                    compact: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _RoundAction(
                  child: IconButton(
                    key: const Key('ledger-close'),
                    tooltip: AppStrings.back,
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/${section.path}'),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          );
          // The total card is always under the ledger, pinned at the bottom
          // (Ali, 2026-11-04). Same card and colour rules as before.
          final total = Padding(
            padding: padding.copyWith(
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: glossyTotal
                ? _TotalCard(
                    section: section,
                    card: loadedCard,
                    money: money,
                    awaitingServerBalance: _balanceAwaitingReload,
                    ackBalance: _ackBalance,
                    reloadError: reloadError,
                  )
                : _Header(
                    section: section,
                    card: loadedCard,
                    money: money,
                    title: _ledgerTitle(section),
                    awaitingServerBalance: _balanceAwaitingReload,
                    ackBalance: _ackBalance,
                    reloadError: reloadError,
                    showTitle: false,
                  ),
          );
          // At large text the total card may be taller than a small
          // screen. It then scrolls inside its own band.
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxPinned = constraints.maxHeight.isFinite
                  ? constraints.maxHeight * 0.34
                  : MediaQuery.sizeOf(context).height * 0.34;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bar,
                  Expanded(
                    child: KeptData<LedgerPage>(
                      value: ledger,
                      resetKey: '${section.path}/$id/ledger',
                      expand: true,
                      onRetry: () =>
                          ref.invalidate(ledgerProvider((section, id))),
                      messageOf: messageOf,
                      failureOf: failureOf,
                      loading: const _LedgerLoading(),
                      builder: (page) => _ledgerBody(
                        context,
                        page: page,
                        card: card,
                        online: online,
                        money: money,
                        canWrite: canWrite,
                        padding: padding,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxPinned),
                    child: SingleChildScrollView(
                      key: const Key('ledger-pinned'),
                      child: total,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Rows oldest first, top to bottom, one continuous record. The entry
  /// buttons sit under the last row. The screen opens scrolled to them.
  Widget _ledgerBody(
    BuildContext context, {
    required LedgerPage page,
    required AsyncValue<AccountCardDto> card,
    required bool online,
    required MoneyFormatter money,
    required bool canWrite,
    required EdgeInsetsDirectional padding,
  }) {
    final resetKey = '${section.path}/$id/${identityHashCode(page)}';
    _syncOlder(resetKey, page);
    // The website's merge: older items first, then the newer page. A row
    // already seen is not repeated.
    final seen = <String>{};
    final all = <LedgerEntryDto>[
      for (final older in _olderPages.reversed)
        for (final entry in older.page.items)
          if (seen.add(entry.id)) entry,
      for (final entry in page.page.items)
        if (seen.add(entry.id)) entry,
    ];
    final complete = _olderCursor == null;
    HistoryWindowTrace.ledgerPage = [
      for (final entry in page.page.items) entry.id,
    ];
    HistoryWindowTrace.ledgerExtra = [
      for (final older in _olderPages)
        for (final entry in older.page.items) entry.id,
    ];
    // Like the website: cancelled (reversed) rows are not drawn. The server
    // keeps them for the audit trail.
    final rows = _oldestFirst(all.where(websiteShowsRow).toList());
    // الرصيد: the website's running balance over every loaded row, shown
    // only when the last row equals the server's stored card balance.
    final balances = complete
        ? websiteBalancesMatchingServer(
            opening: _olderPages.isEmpty
                ? page.pageOpeningBalanceUnits
                : _olderPages.last.pageOpeningBalanceUnits,
            items: all,
            serverBalance:
                page.account?.balanceUnits ?? card.asData?.value.balanceUnits,
          )
        : null;
    final showBalance = balances != null;
    final cardReady = _cardReadyForWrite(card);
    final columns = _LedgerColumns(showBalance: showBalance, section: section);
    final composer = canWrite
        ? _InlineComposer(
            key: const Key('ledger-composer'),
            section: section,
            accountId: id,
            cardReady: cardReady,
            online: online,
            cardVersion: card.asData?.value.version,
            columns: columns,
            onPosted: _posted,
            onFull: (meta) => _full(context, ref, meta),
          )
        : null;
    // م counts the drawn rows 1..n, oldest first, once every page is in.
    Widget row(int index) => _EntryTile(
      key: ValueKey('ledger-row-${rows[index].id}'),
      ordinal: complete ? index + 1 : null,
      balanceUnits: balances?[rows[index].id],
      section: section,
      accountId: id,
      entry: rows[index],
      money: money,
      columns: columns,
      canWrite: canWrite,
      editing: _editingId == rows[index].id,
      onEdit: () => _openInlineEdit(rows[index].id),
      onEditDone: _closeInlineEdit,
      onCancel: (meta) => _cancel(context, ref, rows[index], meta),
    );
    if (_openedAtBottomFor != resetKey) {
      _openedAtBottomFor = resetKey;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEntry());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth - padding.horizontal;
        // Pinned when there is room for it; on a very short screen (e.g.
        // 320x568 at text x2) the names scroll with the rows instead.
        final sticky =
            page.page.items.isNotEmpty && constraints.maxHeight >= 220;
        final table = <Widget>[
          if (!sticky) _LedgerColumnHeader(columns: columns),
          if (!complete)
            _OlderStatus(
              busy: _olderBusy,
              error: _olderError,
              onRetry: () => _loadOlder(resetKey, manual: true),
            ),
          if (rows.length <= HistoryWindow.eagerLimit)
            for (var i = 0; i < rows.length; i++) row(i)
          else
            SizedBox(
              height: 560,
              child: ListView.builder(
                key: const Key('ledger-entries-list'),
                controller: _innerRows,
                itemCount: rows.length,
                itemBuilder: (context, index) => row(index),
              ),
            ),
        ];
        final list = RefreshIndicator(
          key: const Key('ledger-refresh'),
          onRefresh: () async {
            ref.invalidate(ledgerProvider((section, id)));
            ref.invalidate(accountCardProvider((section, id)));
            await ref.read(ledgerProvider((section, id)).future);
          },
          child: ListView(
            key: const Key('ledger-scroll'),
            controller: _rows,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding.copyWith(top: sticky ? 0 : AppSpacing.sm),
            children: [
              _LedgerTable(
                controller: _columnsScroll,
                width: columns.width,
                viewport: viewport,
                attachedTop: sticky,
                composer: composer,
                children: page.page.items.isEmpty
                    ? const [EmptyPane(message: AppStrings.emptyLedger)]
                    : table,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The column names stay on screen while the rows scroll, and
            // follow the rows sideways (Ali, 2026-11-03).
            if (sticky)
              Padding(
                padding: padding.copyWith(top: AppSpacing.sm, bottom: 0),
                child: _StickyColumnHeader(
                  controller: _headerScroll,
                  width: columns.width,
                  viewport: viewport,
                  columns: columns,
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateJumpButtons();
                  return false;
                },
                child: list,
              ),
            ),
          ],
        );
      },
    );
  }

  /// First open: the newest rows and the entry buttons are on screen.
  void _jumpToEntry() {
    if (!mounted) return;
    _toTableStart();
    if (_innerRows.hasClients) {
      _innerRows.jumpTo(_innerRows.position.maxScrollExtent);
    }
    if (_rows.hasClients) {
      _rows.jumpTo(_rows.position.maxScrollExtent);
    }
  }

  void _openInlineEdit(String entryId) {
    setState(() => _editingId = entryId);
    // The form sits at the start of the row, where the table starts.
    if (_columnsScroll.hasClients) {
      _columnsScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _closeInlineEdit(bool saved) {
    if (!mounted) return;
    setState(() => _editingId = null);
    if (!saved) return;
    ref.invalidate(ledgerProvider((section, id)));
    ref.invalidate(accountCardProvider((section, id)));
    ref.invalidate(accountsProvider(section));
  }

  /// After the inline row saved a movement: same refresh as the sheet had.
  void _posted(PostedMovement saved) {
    if (!mounted) return;
    setState(() {
      _balanceAwaitingReload = true;
      _ackBalance = saved.balanceUnits;
    });
    ref.invalidate(ledgerProvider((section, id)));
    ref.invalidate(accountCardProvider((section, id)));
    ref.invalidate(accountsProvider(section));
    ref.invalidate(homeDashboardProvider);
  }

  Future<String?> _full(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) async {
    final balance = ref
        .read(accountCardProvider((section, id)))
        .asData
        ?.value
        .balanceUnits;
    if (balance != null && balance.isInvalid) {
      return AppStrings.invalidAmount;
    }
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .addTransaction(
            section,
            id,
            // No date control on this button. Omit date; the server stamps it.
            AccountTransactionRequest.fullPayment(),
            meta,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountCardProvider((section, id)));
      ref.invalidate(accountsProvider(section));
      ref.invalidate(homeDashboardProvider);
      return null;
    } catch (error) {
      return failureText(ref.read(errorHandlerProvider).toFailure(error));
    }
  }

  Future<String?> _cancel(
    BuildContext context,
    WidgetRef ref,
    LedgerEntryDto entry,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .cancelTransaction(section, id, entry.id, meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountCardProvider((section, id)));
      ref.invalidate(accountsProvider(section));
      ref.invalidate(homeDashboardProvider);
      return null;
    } catch (error) {
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (failure.code == 'VERSION_CONFLICT') {
        ref.invalidate(ledgerProvider((section, id)));
        ref.invalidate(accountCardProvider((section, id)));
        ref.invalidate(accountsProvider(section));
        ref.invalidate(homeDashboardProvider);
      }
      return failureText(failure);
    }
  }
}

/// The add row's height at text scale 1: one row like the posted rows.
const _composerHeight = 60.0;

class _MovementForm extends ConsumerStatefulWidget {
  const _MovementForm({
    required this.section,
    required this.id,
    required this.type,
    this.onSaved,
    this.columns,
    this.typeCell,
    this.onFull,
    super.key,
  });

  final AccountSection section;
  final String id;
  final String type;

  /// Inline row only: the table's columns, the type buttons for the
  /// نوع الحركة cell, and دفع كلي's own request when [type] is `full`.
  final _LedgerColumns? columns;
  final Widget? typeCell;
  final Future<String?> Function(MutationMeta meta)? onFull;

  /// Inline use at the bottom of the ledger table: called after the server
  /// accepted the movement, instead of closing a sheet. Same request.
  final ValueChanged<PostedMovement>? onSaved;

  @override
  ConsumerState<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends ConsumerState<_MovementForm> {
  final _amount = TextEditingController();
  final _factor = TextEditingController();
  final _note = TextEditingController();
  late final TextEditingController _date = TextEditingController(
    text: formatIsoDate(DateTime.now()),
  );
  var _mode = CalculationMode.direct;

  @override
  void initState() {
    super.initState();
    for (final controller in [_amount, _factor, _note, _date]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_amount, _factor, _note, _date]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchedCard = ref.watch(
      accountCardProvider((widget.section, widget.id)),
    );
    if (widget.onSaved != null) return _inline(context, watchedCard);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          movementLabel(section: widget.section, type: widget.type),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(AppStrings.noPreview),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('movement-amount'),
          controller: _amount,
          label: AppStrings.amount,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButton<CalculationMode>(
          value: _mode,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: CalculationMode.direct,
              child: Text(AppStrings.direct),
            ),
            DropdownMenuItem(
              value: CalculationMode.divide,
              child: CalculationMark(CalculationMode.divide),
            ),
            DropdownMenuItem(
              value: CalculationMode.multiply,
              child: CalculationMark(CalculationMode.multiply),
            ),
          ],
          onChanged: (value) =>
              setState(() => _mode = value ?? CalculationMode.direct),
        ),
        if (_mode != CalculationMode.direct)
          TextField(
            controller: _factor,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: AppStrings.factor),
          ),
        TextField(
          controller: _date,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: AppStrings.date),
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: AppStrings.note),
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-movement'),
          allowed: _cardReadyForWrite(watchedCard),
          inputs:
              '${widget.type}|$_mode|${_amount.text}|${_factor.text}|${_date.text}|${_note.text}',
          expectedVersion: watchedCard.asData?.value.version,
          label: AppStrings.save,
          onVersionConflict: () {
            ref.invalidate(ledgerProvider((widget.section, widget.id)));
            ref.invalidate(accountCardProvider((widget.section, widget.id)));
            ref.invalidate(accountsProvider(widget.section));
            ref.invalidate(homeDashboardProvider);
          },
          onSubmit: _submit,
        ),
        // The save button stays hidden while the card reload has failed, so
        // no write goes out without a settled version. Say why instead of
        // leaving the form without a button and without a word.
        if (watchedCard.hasError)
          Semantics(
            container: true,
            excludeSemantics: true,
            label: AppStrings.movementCardReloadFailed,
            child: const Text(
              AppStrings.movementCardReloadFailed,
              key: Key('movement-reload-failed'),
            ),
          ),
      ],
    );
  }

  /// The add row: the last, highlighted row of the ledger grid, one field
  /// per column (التاريخ، نوع الحركة، البيان، القيمة، العملية، السعر، ✓).
  /// Same fields, checks, and request as the sheet.
  Widget _inline(BuildContext context, AsyncValue<AccountCardDto> watchedCard) {
    final look = context.look;
    final columns = widget.columns!;
    final full = widget.type == 'full';
    final small = cairo(10.5, 500, color: look.muted);
    final dash = Text(AppStrings.dash, style: small);
    InputDecoration field(String label, {Widget? prefix}) => InputDecoration(
      hintText: label,
      hintStyle: cairo(11.5, 600, color: look.muted),
      isDense: true,
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 26),
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 8,
      ),
    );
    final note = TextField(
      key: const Key('movement-note'),
      controller: _note,
      enabled: !full,
      style: cairo(12, 600),
      decoration: field(AppStrings.ledgerColNote),
    );
    final amount = UnitsField(
      key: const Key('movement-amount'),
      controller: _amount,
      label: AppStrings.ledgerColValue,
      dense: true,
      showHint: false,
      // Ready to type on entry and after each save (Ali, 2026-11-03).
      autofocus: !full,
    );
    final rate = TextField(
      key: const Key('movement-factor'),
      controller: _factor,
      enabled: !full && _mode != CalculationMode.direct,
      textDirection: TextDirection.ltr,
      style: cairo(12, 600),
      decoration: field(AppStrings.ledgerColRate),
    );
    final date = TextField(
      key: const Key('movement-date'),
      controller: _date,
      enabled: !full,
      textDirection: TextDirection.ltr,
      style: cairo(11.5, 600),
      decoration: field(
        AppStrings.date,
        prefix: const Icon(Icons.calendar_today_outlined, size: 14),
      ),
    );
    final modes = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 3,
      children: [
        for (final mode in const [
          CalculationMode.direct,
          CalculationMode.divide,
          CalculationMode.multiply,
        ])
          ChoiceChip(
            key: Key('movement-mode-${mode.name}'),
            label: CalculationMark(mode),
            selected: _mode == mode,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            onSelected: full ? null : (_) => setState(() => _mode = mode),
          ),
      ],
    );
    final Widget save = full
        ? GuardedMutation(
            buttonKey: const Key('full-payment'),
            allowed: _cardReadyForWrite(watchedCard),
            inputs: 'full:${watchedCard.asData?.value.version}',
            expectedVersion: watchedCard.asData?.value.version,
            label: AppStrings.save,
            glyph: Icons.check_rounded,
            onSubmit: widget.onFull!,
          )
        : GuardedMutation(
            buttonKey: const Key('save-movement'),
            allowed: _cardReadyForWrite(watchedCard),
            inputs:
                '${widget.type}|$_mode|${_amount.text}|${_factor.text}|${_date.text}|${_note.text}',
            expectedVersion: watchedCard.asData?.value.version,
            label: AppStrings.save,
            glyph: Icons.check_rounded,
            onVersionConflict: () {
              ref.invalidate(ledgerProvider((widget.section, widget.id)));
              ref.invalidate(accountCardProvider((widget.section, widget.id)));
              ref.invalidate(accountsProvider(widget.section));
              ref.invalidate(homeDashboardProvider);
            },
            onSubmit: _submit,
          );
    // ✓ in the first (rightmost) cell: on screen at the RTL start, no
    // swipe. An error line may spill under the row.
    final saveCell = OverflowBox(
      maxWidth: 240,
      maxHeight: double.infinity,
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, top: 10),
        child: SectionTheme(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Theme(
                data: theme.copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: theme.filledButtonTheme.style?.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
                      fixedSize: const WidgetStatePropertyAll(Size(40, 40)),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      shape: const WidgetStatePropertyAll(CircleBorder()),
                    ),
                  ),
                ),
                child: save,
              );
            },
          ),
        ),
      ),
    );
    final viewport = _InlineViewport.of(context);
    return Column(
      key: const Key('movement-inline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: look.accent.withValues(alpha: 0.10),
            border: Border(
              top: BorderSide(color: look.accent, width: 1.5),
              bottom: BorderSide(color: _gridLine(context)),
            ),
          ),
          // A fixed height (scaled with the text): the save button does not
          // report an intrinsic height.
          child: SizedBox(
            height: MediaQuery.textScalerOf(context).scale(_composerHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cell(_LedgerColumns.seq, saveCell),
                _Cell(_LedgerColumns.when, date),
                _Cell(_LedgerColumns.by, dash),
                _Cell(
                  _LedgerColumns.type,
                  widget.typeCell == null
                      ? dash
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: widget.typeCell,
                        ),
                ),
                _Cell(_LedgerColumns.note, note),
                _Cell(_LedgerColumns.value, full ? dash : amount),
                _Cell(
                  _LedgerColumns.operation,
                  FittedBox(fit: BoxFit.scaleDown, child: modes),
                ),
                _Cell(_LedgerColumns.rate, rate),
                // No preview on the phone: figures come from the server.
                _Cell(_LedgerColumns.debt, dash),
                _Cell(_LedgerColumns.paid, dash),
                if (columns.showBalance) _Cell(_LedgerColumns.balance, dash),
                _Cell(
                  _LedgerColumns.edit + _LedgerColumns.cancel,
                  dash,
                  divider: false,
                ),
              ],
            ),
          ),
        ),
        if (full || watchedCard.hasError)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: viewport,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (full)
                      Text(
                        AppStrings.fullPaymentHint,
                        style: cairo(12, 500, color: look.muted),
                      ),
                    if (watchedCard.hasError)
                      Semantics(
                        container: true,
                        excludeSemantics: true,
                        label: AppStrings.movementCardReloadFailed,
                        child: const Text(
                          AppStrings.movementCardReloadFailed,
                          key: Key('movement-reload-failed'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    if (units == null) return AppStrings.integerOnly;
    // Direct partial payment only. A rate is not an amount, so it is not
    // compared. An invalid balance is refused. It is not treated as 0.
    // The warning uses the balance already on the card. It does not read
    // the card again, so a failed read cannot block the send. An amount
    // above that balance is not refused. Cancel returns an empty string
    // and sends nothing. Null would be treated as success and would drop
    // this form's request id. The empty string is not shown.
    if (widget.type == 'payment' && _mode == CalculationMode.direct) {
      final loaded = ref
          .read(accountCardProvider((widget.section, widget.id)))
          .asData
          ?.value;
      final watched = loaded?.balanceUnits;
      if (watched != null && watched.isInvalid) {
        return AppStrings.invalidAmount;
      }
      final remainingUnits = watched?.asInt;
      if (loaded != null && remainingUnits != null && units > remainingUnits) {
        final proceed = await _confirmOverpayment(
          loaded.currency,
          remainingUnits,
          units,
        );
        if (!mounted || proceed != true) return '';
      }
    }
    final parsedDate = DateTime.tryParse(_date.text);
    if (parsedDate == null) return AppStrings.dateInvalid;
    DecimalString? factorValue;
    if (_mode != CalculationMode.direct) {
      factorValue = DecimalString.tryParse(_factor.text);
      if (factorValue == null) return AppStrings.rateInvalid;
    }
    final request = widget.type == 'payment'
        ? AccountTransactionRequest.partialPayment(
            inputValue: units,
            mode: _mode,
            factor: factorValue,
            date: parsedDate,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          )
        : AccountTransactionRequest.debt(
            inputValue: units,
            mode: _mode,
            factor: factorValue,
            date: parsedDate,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .accounts
          .addTransaction(widget.section, widget.id, request, meta);
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      final posted = PostedMovement(balanceUnits: ack.balanceUnits);
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        onSaved(posted);
      } else {
        Navigator.of(context).pop(posted);
      }
      return null;
    } catch (error) {
      // A returned string never reaches GuardedMutation's conflict path.
      // Rethrow so it refetches and shows the shared conflict sentence.
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (failure.code == 'VERSION_CONFLICT') rethrow;
      return failureText(failure);
    }
  }

  /// Null or false sends nothing. True continues with the same [MutationMeta].
  Future<bool?> _confirmOverpayment(
    Currency currency,
    int currentUnits,
    int enteredUnits,
  ) {
    final money = ref.read(apiLayerProvider).money;
    final current = money.format(currentUnits, currency);
    final entered = money.format(enteredUnits, currency);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return RepaintBoundary(
          key: const Key('overpayment-boundary'),
          child: AlertDialog(
            key: const Key('overpayment-warning'),
            content: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '${AppStrings.overpaymentCurrent} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: MoneyText(
                      current,
                      key: const Key('overpayment-current'),
                    ),
                  ),
                  const TextSpan(text: ' ${AppStrings.overpaymentEntered} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: MoneyText(
                      entered,
                      key: const Key('overpayment-entered'),
                    ),
                  ),
                  const TextSpan(text: '. ${AppStrings.overpaymentAsk}'),
                ],
              ),
              key: const Key('overpayment-copy'),
            ),
            actions: [
              TextButton(
                key: const Key('overpayment-cancel'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                key: const Key('overpayment-continue'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(AppStrings.overpaymentAsk),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.card,
    required this.money,
    required this.title,
    this.awaitingServerBalance = false,
    this.ackBalance,
    this.reloadError,
    this.showTitle = true,
  });

  /// False when the screen bar above already names the ledger.
  final bool showTitle;

  final AccountSection section;
  final AccountCardDto? card;
  final MoneyFormatter money;
  final String title;

  /// The payment response has not been replaced by a completed card reload.
  final bool awaitingServerBalance;

  /// [MutationAck.balanceUnits] while [awaitingServerBalance] is set.
  final MoneyValue? ackBalance;

  /// Set when the card reload after that acknowledgement failed.
  /// The figure stays [ackBalance]. This is the reload failure, not a new balance.
  final String? reloadError;

  @override
  Widget build(BuildContext context) {
    final value = card;
    if (value == null) return const SkeletonBox(height: 48);
    final width = MediaQuery.sizeOf(context).width;
    final colors = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final visual = ageVisual(
      colors: colors,
      ageStatus: value.ageStatus,
      section: section,
      serverLabel: value.ageStatusLabel,
    );
    final flat = useFlatAgeCard(width, Theme.of(context).brightness);
    final colored = visual.colored;
    final foreground = colored ? colors.onStatus : scheme.onSurface;
    final accent = colored
        ? (visual.accent ?? colors.onStatus)
        : scheme.onSurfaceVariant;
    // A credit balance uses the same ink as any other balance on this card.
    final shownBalance = awaitingServerBalance
        ? ackBalance
        : value.balanceUnits;
    final balanceColor = foreground;
    // Customers: the word comes from the sign of the server balance. أمانة
    // shows the figure without its minus sign (Ali, 2026-11-03). Display
    // only; nothing is computed from it.
    final kind = section == AccountSection.customers
        ? customerBalanceKind(shownBalance)
        : CustomerBalanceKind.unknown;
    final kindWord = switch (kind) {
      CustomerBalanceKind.debt => AppStrings.customerDebtWord,
      CustomerBalanceKind.credit => AppStrings.customerCreditWord,
      CustomerBalanceKind.zero => AppStrings.ledgerZeroWord,
      CustomerBalanceKind.unknown => null,
    };
    final units = shownBalance?.asInt;
    final shownText = kind == CustomerBalanceKind.credit && units != null
        ? money.format(-units, value.currency)
        : money.formatOrDash(shownBalance, value.currency);
    return Material(
      key: const Key('ledger-header'),
      color: colored
          ? (flat ? visual.flat : colors.neutralCard)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: colored && !flat ? visual.gradient : null,
          color: colored && flat ? visual.flat : null,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: value.ageStatus == 'zero'
                ? colors.zeroCardBorder
                : colored
                ? colors.onStatus.withValues(alpha: 0.2)
                : scheme.outline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showTitle)
                    Text(title, style: cairo(16, 800, color: foreground)),
                ],
              ),
              Text(
                section == AccountSection.libyanDeposits ||
                        section == AccountSection.egyptianDeposits
                    ? AppStrings.ledgerDepositTotal
                    : AppStrings.ledgerTotal,
                key: const Key('ledger-total-heading'),
                style: cairo(12, 600, color: accent),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MoneyText(
                    shownText,
                    key: const Key('ledger-header-balance'),
                    style: context.textExtras.amountLarge.copyWith(
                      color: balanceColor,
                    ),
                  ),
                  if (kindWord != null)
                    DecoratedBox(
                      key: const Key('ledger-header-kind'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: foreground.withValues(alpha: 0.45),
                        ),
                        color: foreground.withValues(alpha: 0.1),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        child: Text(
                          kindWord,
                          style: cairo(12, 800, color: foreground),
                        ),
                      ),
                    ),
                ],
              ),
              if (reloadError != null)
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: AppStrings.ledgerReloadFailed,
                  child: Text(
                    AppStrings.ledgerReloadFailed,
                    key: const Key('ledger-reload-failed'),
                    style: cairo(12, 500, color: accent),
                  ),
                ),
              if (value.systemManaged)
                Text(
                  AppStrings.systemCard,
                  key: ValueKey('system-${value.systemLinkKey ?? 'managed'}'),
                  style: cairo(12, 700, color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The customers' total card: glossy red for دين, green for أمانة (no
/// minus sign), glossy black with white text for صفر, in both themes
/// (Ali, 2026-11-03). The word and colour come from the sign of the server
/// balance only.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.section,
    required this.card,
    required this.money,
    this.awaitingServerBalance = false,
    this.ackBalance,
    this.reloadError,
  });

  final AccountSection section;
  final AccountCardDto card;
  final MoneyFormatter money;
  final bool awaitingServerBalance;
  final MoneyValue? ackBalance;
  final String? reloadError;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final shown = awaitingServerBalance ? ackBalance : card.balanceUnits;
    final Gloss gloss;
    final String? word;
    final String heading;
    final bool credit;
    if (section == AccountSection.companies) {
      final kind = companyLedgerKind(shown);
      gloss = switch (kind) {
        CompanyLedgerKind.debt => look.glossDebt,
        CompanyLedgerKind.credit => look.glossCredit,
        CompanyLedgerKind.zero => look.glossZero,
        CompanyLedgerKind.unknown => look.glossGrey,
      };
      word = switch (kind) {
        CompanyLedgerKind.debt => AppStrings.customerDebtWord,
        CompanyLedgerKind.credit => AppStrings.customerCreditWord,
        CompanyLedgerKind.zero => AppStrings.ledgerZeroWord,
        CompanyLedgerKind.unknown => null,
      };
      heading = companyLedgerHeading(kind);
      credit = kind == CompanyLedgerKind.credit;
    } else {
      final kind = customerBalanceKind(shown);
      gloss = switch (kind) {
        CustomerBalanceKind.debt => look.glossDebt,
        CustomerBalanceKind.credit => look.glossCredit,
        CustomerBalanceKind.zero => look.glossZero,
        CustomerBalanceKind.unknown => look.glossGrey,
      };
      word = switch (kind) {
        CustomerBalanceKind.debt => AppStrings.customerDebtWord,
        CustomerBalanceKind.credit => AppStrings.customerCreditWord,
        CustomerBalanceKind.zero => AppStrings.ledgerZeroWord,
        CustomerBalanceKind.unknown => null,
      };
      heading = AppStrings.ledgerTotal;
      credit = kind == CustomerBalanceKind.credit;
    }
    final units = shown?.asInt;
    final text = credit && units != null
        ? money.format(-units, card.currency)
        : money.formatOrDash(shown, card.currency);
    final radius = BorderRadius.circular(AppRadii.card);
    return Material(
      key: const Key('ledger-header'),
      type: MaterialType.transparency,
      child: Ink(
        decoration: gloss
            .decoration(radius)
            .copyWith(boxShadow: gloss.glowShadow),
        child: GlossSheen(
          gloss: gloss,
          radius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            // Only the total, centred: heading, figure and word. The name
            // and phone are already above the ledger (Ali, 2026-11-04).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading,
                  key: const Key('ledger-total-heading'),
                  textAlign: TextAlign.center,
                  style: cairo(12, 700, color: gloss.ink),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(
                          text,
                          key: const Key('ledger-header-balance'),
                          style: context.textExtras.amountLarge.copyWith(
                            color: gloss.amount,
                          ),
                        ),
                      ),
                    ),
                    if (word != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      DecoratedBox(
                        key: const Key('ledger-header-kind'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: gloss.ink.withValues(alpha: 0.12),
                          border: Border.all(
                            color: gloss.ink.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xxs,
                          ),
                          child: Text(
                            word,
                            style: cairo(13, 800, color: gloss.amount),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (reloadError != null)
                  Semantics(
                    container: true,
                    excludeSemantics: true,
                    label: AppStrings.ledgerReloadFailed,
                    child: Text(
                      AppStrings.ledgerReloadFailed,
                      key: const Key('ledger-reload-failed'),
                      style: cairo(12, 600, color: gloss.ink),
                    ),
                  ),
                if (card.systemManaged)
                  Text(
                    AppStrings.systemCard,
                    key: ValueKey('system-${card.systemLinkKey ?? 'managed'}'),
                    style: cairo(12, 700, color: gloss.ink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// While older pages are still arriving: a quiet progress line, or the
/// error with a retry. The table has no م numbers until every page is in.
class _OlderStatus extends StatelessWidget {
  const _OlderStatus({
    required this.busy,
    required this.error,
    required this.onRetry,
  });

  final bool busy;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: busy || error == null
            ? Row(
                key: const Key('ledger-loading-older'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.ledgerLoadingOlder,
                    style: cairo(12, 600, color: look.muted),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      error!,
                      key: const Key('load-older-error'),
                      style: cairo(12, 600, color: scheme.error),
                    ),
                  ),
                  TextButton(
                    key: const Key('load-older'),
                    onPressed: onRetry,
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Rows in ascending [LedgerEntryDto.sequence], the website order. A row
/// without a sequence keeps its place after the numbered rows. Display only.
List<LedgerEntryDto> _oldestFirst(List<LedgerEntryDto> items) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final sa = a.$2.sequence;
    final sb = b.$2.sequence;
    if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
    if (sa == null && sb != null) return 1;
    if (sa != null && sb == null) return -1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final pair in indexed) pair.$2];
}

/// Column widths of the ledger table, in the website's order. Narrow
/// enough that م to البيان fit a phone before the swipe.
class _LedgerColumns {
  const _LedgerColumns({required this.showBalance, required this.section});

  final bool showBalance;
  final AccountSection section;

  static const seq = 56.0;
  static const when = 112.0;
  static const by = 76.0;
  static const type = 164.0;
  static const note = 108.0;
  static const value = 84.0;
  static const operation = 128.0;
  static const rate = 76.0;
  static const debt = 92.0;
  static const paid = 92.0;
  static const balance = 92.0;
  static const edit = 52.0;
  static const cancel = 52.0;

  bool get _deposits =>
      section == AccountSection.libyanDeposits ||
      section == AccountSection.egyptianDeposits;

  /// The section's own debit / credit column names, as on the website.
  String get debtLabel => _deposits
      ? movementLabel(section: section, type: 'debt')
      : AppStrings.ledgerColDebt;
  String get paidLabel => _deposits
      ? movementLabel(section: section, type: 'payment')
      : AppStrings.ledgerColPaid;

  double get width =>
      seq +
      when +
      by +
      type +
      note +
      value +
      operation +
      rate +
      debt +
      paid +
      (showBalance ? balance : 0) +
      edit +
      cancel;
}

/// The table card: one horizontal scroll for every row, the add row at the
/// bottom inside the same card, and a footer strip.
class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.controller,
    required this.width,
    required this.viewport,
    required this.children,
    this.composer,
    this.attachedTop = false,
  });

  final ScrollController controller;
  final double width;
  final double viewport;
  final List<Widget> children;
  final Widget? composer;

  /// The sticky column names sit right above, so the top is square.
  final bool attachedTop;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final corner = Radius.circular(AppRadii.card);
    final radius = attachedTop
        ? BorderRadius.vertical(bottom: corner)
        : BorderRadius.all(corner);
    final tableWidth = width > viewport ? width : viewport;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: const Key('ledger-table'),
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: radius,
        border: Border.all(color: _gridLine(context)),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x55000000) : const Color(0x140F172A),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              key: const Key('ledger-columns-scroll'),
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: _InlineViewport(
                  width: viewport,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...children, ?composer],
                  ),
                ),
              ),
            ),
            if (width > viewport)
              Container(
                color: look.strip,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    if (width > viewport)
                      Flexible(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            child: Text(
                              AppStrings.ledgerSwipeMore,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cairo(
                                10.5,
                                800,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The column names, pinned above the scrolling rows. Its own sideways
/// scroll follows the rows' scroll (and the other way round).
class _StickyColumnHeader extends StatelessWidget {
  const _StickyColumnHeader({
    required this.controller,
    required this.width,
    required this.viewport,
    required this.columns,
  });

  final ScrollController controller;
  final double width;
  final double viewport;
  final _LedgerColumns columns;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final radius = BorderRadius.vertical(top: Radius.circular(AppRadii.card));
    return DecoratedBox(
      key: const Key('ledger-sticky-header'),
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: radius,
        border: Border.all(color: _gridLine(context)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SingleChildScrollView(
          key: const Key('ledger-header-scroll'),
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width > viewport ? width : viewport,
            child: _LedgerColumnHeader(columns: columns),
          ),
        ),
      ),
    );
  }
}

/// Small "first movement" / "latest movement" buttons, shown only when the
/// list is away from that end. Navigation only.
class _JumpButtons extends StatelessWidget {
  const _JumpButtons({
    required this.showTop,
    required this.showBottom,
    required this.onTop,
    required this.onBottom,
  });

  final bool showTop;
  final bool showBottom;
  final VoidCallback onTop;
  final VoidCallback onBottom;

  @override
  Widget build(BuildContext context) {
    if (!showTop && !showBottom) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    Widget button(Key key, IconData icon, String tip, VoidCallback onTap) =>
        IconButton.filledTonal(
          key: key,
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          color: scheme.primary,
          onPressed: onTap,
          icon: Icon(icon),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTop)
          button(
            const Key('ledger-jump-top'),
            Icons.vertical_align_top_rounded,
            AppStrings.ledgerJumpTop,
            onTop,
          ),
        if (showBottom)
          button(
            const Key('ledger-jump-bottom'),
            Icons.vertical_align_bottom_rounded,
            AppStrings.ledgerJumpBottom,
            onBottom,
          ),
      ],
    );
  }
}

/// Gives rows the visible width so an inline form fits the screen.
class _InlineViewport extends InheritedWidget {
  const _InlineViewport({required this.width, required super.child});

  final double width;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InlineViewport>()?.width ??
      MediaQuery.sizeOf(context).width;

  @override
  bool updateShouldNotify(_InlineViewport oldWidget) =>
      oldWidget.width != width;
}

/// The ledger's grid lines: column dividers and row lines, like the website
/// table (Ali, 2026-11-03). Subtle, but clearly visible in both themes.
Color _gridLine(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF2E3A57)
    : const Color(0xFFD3DCE8);

class _Cell extends StatelessWidget {
  const _Cell(this.width, this.child, {this.alignment, this.divider = true});

  final double width;
  final Widget child;
  final AlignmentGeometry? alignment;

  /// A vertical line on the cell's end side; off for the last column.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: divider
          ? BoxDecoration(
              border: BorderDirectional(
                end: BorderSide(color: _gridLine(context)),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 3,
          vertical: AppSpacing.sm,
        ),
        child: Align(
          alignment: alignment ?? AlignmentDirectional.center,
          child: child,
        ),
      ),
    );
  }
}

/// A figure that shrinks to its cell instead of overflowing at large text.
class _Fit extends StatelessWidget {
  const _Fit(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: child);
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.section,
    required this.accountId,
    required this.entry,
    required this.money,
    required this.columns,
    required this.canWrite,
    required this.editing,
    required this.onEdit,
    required this.onEditDone,
    required this.onCancel,
    this.ordinal,
    this.balanceUnits,
    super.key,
  });

  /// الرصيد after this row, from [websiteRunningBalances].
  final int? balanceUnits;

  /// م: this row's place among the drawn rows, 1 = the first movement.
  /// Null while older pages are still loading.
  final int? ordinal;

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;
  final MoneyFormatter money;
  final _LedgerColumns columns;
  final bool canWrite;
  final bool editing;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEditDone;
  final Future<String?> Function(MutationMeta meta) onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reversed = entry.status == 'reversed';
    final look = context.look;
    final scheme = Theme.of(context).colorScheme;
    final muted = reversed ? scheme.onSurfaceVariant : scheme.onSurface;
    final strike = reversed ? TextDecoration.lineThrough : null;
    final body = cairo(12, 600, color: muted).copyWith(decoration: strike);
    final small = cairo(
      10.5,
      500,
      color: look.muted,
    ).copyWith(decoration: strike);
    final number = context.textExtras.tableNumber.copyWith(
      fontSize: 12.5,
      color: muted,
      decoration: strike,
    );
    final sequence = ordinal == null ? AppStrings.dash : '$ordinal';
    final date = entry.date;
    final isPayment = entry.type == 'payment';
    final amountColor = _movementAmountColor(
      context,
      section,
      entry.type,
      reversed ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    final amount = MoneyText(
      money.formatOrDash(entry.amountUnits, section.currency),
      key: Key('ledger-amount-${entry.id}'),
      style: context.textExtras.amount.copyWith(
        fontSize: 13,
        color: amountColor,
        decoration: strike,
      ),
    );
    final dash = Text(AppStrings.dash, style: small);
    // The server checks cancel against the CARD version (`customerVersion`),
    // not a ledger line version. Production ledger lines carry no `version`.
    final cardVersion = ref
        .watch(accountCardProvider((section, accountId)))
        .asData
        ?.value
        .version;
    final cancel = canWrite && !reversed
        ? GuardedMutation(
            buttonKey: Key('cancel-${entry.id}'),
            inputs: 'cancel:${entry.id}:$cardVersion',
            expectedVersion: cardVersion,
            filled: false,
            label: AppStrings.cancelMovement,
            icon: Icons.close_rounded,
            tooltip: AppStrings.cancelMovement,
            confirmText: AppStrings.confirmCancel,
            onSubmit: onCancel,
          )
        : dash;
    final correct = TransactionCorrectionLauncher(
      section: section,
      accountId: accountId,
      entry: entry,
      onOpen: onEdit,
      compact: true,
    );
    final cells = <Widget>[
      _Cell(
        _LedgerColumns.seq,
        _SequenceMark(
          key: Key('ledger-sequence-${entry.id}'),
          text: sequence,
          style: number.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      _Cell(
        _LedgerColumns.when,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (date != null)
              Text(AppStrings.weekdays[date.weekday - 1], style: small),
            _Fit(
              LtrText(
                formatIsoDate(date),
                key: Key('ledger-date-${entry.id}'),
                style: number,
              ),
            ),
            if (date != null) LtrText(_clock(date), style: small),
          ],
        ),
      ),
      _Cell(
        _LedgerColumns.by,
        entry.createdByName == null
            ? dash
            : _ByChip(entry.createdByName!, reversed: reversed),
      ),
      _Cell(
        _LedgerColumns.type,
        _TypeChip(
          label: movementLabel(
            section: section,
            type: entry.type,
            paymentMode: entry.paymentMode,
          ),
          kind: _chipKind(section, entry),
          reversed: reversed,
        ),
      ),
      _Cell(
        _LedgerColumns.note,
        alignment: AlignmentDirectional.centerStart,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (entry.note ?? '').trim().isEmpty ? AppStrings.dash : entry.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: body,
            ),
            if (reversed)
              Text(
                AppStrings.reversed,
                style: cairo(10.5, 800, color: scheme.onSurfaceVariant),
              ),
            if (entry.corrected)
              Text(AppStrings.corrected, style: cairo(10.5, 800, color: muted)),
          ],
        ),
      ),
      _Cell(_LedgerColumns.value, _Fit(_InputFigure(entry.inputValue, number))),
      _Cell(
        _LedgerColumns.operation,
        _Fit(CalculationMark(entry.calculationMode, style: body)),
      ),
      _Cell(
        _LedgerColumns.rate,
        entry.factorMicros == null
            ? dash
            : _Fit(_FactorFigure(entry.factorMicros!, money, number)),
      ),
      _Cell(_LedgerColumns.debt, isPayment ? dash : _Fit(amount)),
      _Cell(_LedgerColumns.paid, isPayment ? _Fit(amount) : dash),
      if (columns.showBalance)
        _Cell(
          _LedgerColumns.balance,
          balanceUnits == null
              ? dash
              : _Fit(
                  MoneyText(
                    money.format(balanceUnits!, section.currency),
                    key: Key('ledger-balance-${entry.id}'),
                    style: number.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
        ),
      _Cell(_LedgerColumns.edit, correct),
      _Cell(_LedgerColumns.cancel, cancel, divider: false),
    ];
    final viewport = _InlineViewport.of(context);
    // Zebra by the row number, so every page stripes the same way.
    final odd = (ordinal ?? entry.sequence ?? 0).isOdd;
    final zebra = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.025)
        : const Color(0xFF0F172A).withValues(alpha: 0.025);
    return Column(
      key: Key('ledger-entry-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: reversed
                ? scheme.surfaceContainerHighest
                : editing
                ? look.strip
                : odd
                ? null
                : zebra,
            border: Border(bottom: BorderSide(color: _gridLine(context))),
          ),
          // Full-height cells so the column lines run unbroken.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          ),
        ),
        if (editing)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: viewport,
              child: DecoratedBox(
                key: Key('ledger-inline-edit-${entry.id}'),
                decoration: BoxDecoration(
                  color: look.strip,
                  border: Border(bottom: BorderSide(color: look.cardBorder)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TransactionCorrectionForm(
                        section: section,
                        accountId: accountId,
                        entry: entry,
                        onDone: onEditDone,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          key: Key('close-inline-edit-${entry.id}'),
                          onPressed: () => onEditDone(false),
                          child: const Text(AppStrings.ledgerCloseEdit),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _clock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final half = value.hour < 12 ? 'ص' : 'م';
  return '$hour:$minute $half';
}

enum _ChipKind { debt, partial, full }

/// ديون red, دفع جزئي green, دفع كلي glossy black. From the server's type
/// and paymentMode only.
_ChipKind _chipKind(AccountSection section, LedgerEntryDto entry) {
  // Deposits, as on the website: إيداع green, سحب red. Colour only.
  if (section == AccountSection.libyanDeposits ||
      section == AccountSection.egyptianDeposits) {
    return entry.type == 'payment' ? _ChipKind.debt : _ChipKind.partial;
  }
  if (entry.type != 'payment') return _ChipKind.debt;
  if (entry.paymentMode == 'full') return _ChipKind.full;
  return _ChipKind.partial;
}

/// Solid glossy chip colours, white text, in both themes (the mockup).
LinearGradient _chipFill(BuildContext context, _ChipKind kind) {
  final look = context.look;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final status = context.statusColors;
  Color lift(Color c) => Color.lerp(c, Colors.white, 0.18)!;
  final colors = switch (kind) {
    _ChipKind.full => [look.glossZero.top, look.glossZero.bottom],
    _ChipKind.debt =>
      dark
          ? [look.glossDebt.top, look.glossDebt.bottom]
          : [lift(status.debtText), status.debtText],
    _ChipKind.partial =>
      dark
          ? [look.glossCredit.top, look.glossCredit.bottom]
          : [lift(status.creditText), status.creditText],
  };
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.kind,
    required this.reversed,
  });

  final String label;
  final _ChipKind kind;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: reversed ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _chipFill(context, kind),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: cairo(11.5, 800, color: Colors.white).copyWith(
              decoration: reversed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The add row at the bottom of the table, like the website: choose
/// ديون / دفع جزئي / دفع كلي, then the same fields and request as before.
class _InlineComposer extends StatefulWidget {
  const _InlineComposer({
    required this.section,
    required this.accountId,
    required this.cardReady,
    required this.online,
    required this.cardVersion,
    required this.onPosted,
    required this.onFull,
    required this.columns,
    super.key,
  });

  final _LedgerColumns columns;
  final AccountSection section;
  final String accountId;
  final bool cardReady;
  final bool online;
  final int? cardVersion;
  final ValueChanged<PostedMovement> onPosted;
  final Future<String?> Function(MutationMeta meta) onFull;

  @override
  State<_InlineComposer> createState() => _InlineComposerState();
}

class _InlineComposerState extends State<_InlineComposer> {
  var _type = 'debt';

  /// A new round after each accepted movement: fresh fields, new request id.
  var _round = 0;

  bool get _deposits =>
      widget.section == AccountSection.libyanDeposits ||
      widget.section == AccountSection.egyptianDeposits;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final enabled = widget.online;
    Widget chip(Key key, String label, String type, _ChipKind kind) {
      final selected = _type == type;
      final fill = _chipFill(context, kind);
      return FilledButton(
        key: key,
        style: FilledButton.styleFrom(
          backgroundColor: selected ? fill.colors.last : look.card,
          foregroundColor: selected ? Colors.white : look.ink,
          side: BorderSide(
            color: selected ? fill.colors.first : look.cardBorder,
          ),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 30),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
        ),
        onPressed: enabled ? () => setState(() => _type = type) : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: cairo(12, 800)),
        ),
      );
    }

    // The section's own type buttons, stacked in the نوع الحركة cell.
    final chips = widget.cardReady
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              chip(
                const Key('add-debt'),
                _deposits
                    ? movementLabel(section: widget.section, type: 'debt')
                    : AppStrings.debtMovement,
                'debt',
                _deposits ? _ChipKind.partial : _ChipKind.debt,
              ),
              const SizedBox(width: 3),
              chip(
                const Key('add-payment'),
                _deposits
                    ? movementLabel(section: widget.section, type: 'payment')
                    : AppStrings.paymentMovement,
                'payment',
                _deposits ? _ChipKind.debt : _ChipKind.partial,
              ),
              if (!_deposits) ...[
                const SizedBox(width: 3),
                chip(
                  const Key('composer-full'),
                  AppStrings.fullPayment,
                  'full',
                  _ChipKind.full,
                ),
              ],
            ],
          )
        : null;
    return _MovementForm(
      key: ValueKey('movement-$_type-$_round'),
      section: widget.section,
      id: widget.accountId,
      type: _type == 'full' && _deposits ? 'debt' : _type,
      columns: widget.columns,
      typeCell: chips,
      onFull: widget.onFull,
      onSaved: (posted) {
        // A fresh row, back on ديون (Ali, 2026-11-03).
        setState(() {
          _round++;
          _type = 'debt';
        });
        widget.onPosted(posted);
      },
    );
  }
}

/// Debt lines use [AppStatusColors.debtText]. Payment lines use
/// [AppStatusColors.creditText]. Other types stay on the surface colour.
Color _movementAmountColor(
  BuildContext context,
  AccountSection section,
  String type,
  Color fallback,
) {
  final colors = context.statusColors;
  if (section == AccountSection.libyanDeposits ||
      section == AccountSection.egyptianDeposits) {
    return type == 'payment' ? colors.debtText : colors.creditText;
  }
  return switch (type) {
    'debt' => colors.debtText,
    'payment' => colors.creditText,
    _ => fallback,
  };
}

String _ledgerTitle(AccountSection section) => switch (section) {
  AccountSection.customers => AppStrings.customerLedger,
  AccountSection.companies => AppStrings.companyLedger,
  AccountSection.libyanDeposits => AppStrings.libyanLedger,
  AccountSection.egyptianDeposits => AppStrings.egyptianLedger,
};

class _LedgerLoading extends StatelessWidget {
  const _LedgerLoading();

  @override
  Widget build(BuildContext context) {
    // The rows area under the pinned card can be short at large text.
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(key: Key('ledger-loading'), height: 112),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 84),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 84),
        ],
      ),
    );
  }
}

class _LedgerColumnHeader extends StatelessWidget {
  const _LedgerColumnHeader({required this.columns});

  final _LedgerColumns columns;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final style = cairo(11, 700, color: look.muted);
    Widget head(double width, String text, {bool divider = true}) => _Cell(
      width,
      Text(text, style: style, textAlign: TextAlign.center),
      divider: divider,
    );
    return DecoratedBox(
      key: const Key('ledger-column-header'),
      decoration: BoxDecoration(
        color: look.strip,
        border: Border(
          bottom: BorderSide(color: _gridLine(context), width: 1.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head(_LedgerColumns.seq, AppStrings.ledgerColSeq),
            head(_LedgerColumns.when, AppStrings.ledgerColWhen),
            head(_LedgerColumns.by, AppStrings.ledgerColBy),
            head(_LedgerColumns.type, AppStrings.ledgerColType),
            head(_LedgerColumns.note, AppStrings.ledgerColNote),
            head(_LedgerColumns.value, AppStrings.ledgerColValue),
            head(_LedgerColumns.operation, AppStrings.ledgerColOperation),
            head(_LedgerColumns.rate, AppStrings.ledgerColRate),
            head(_LedgerColumns.debt, columns.debtLabel),
            head(_LedgerColumns.paid, columns.paidLabel),
            if (columns.showBalance)
              head(_LedgerColumns.balance, AppStrings.ledgerColBalance),
            head(_LedgerColumns.edit, AppStrings.ledgerColEdit),
            head(
              _LedgerColumns.cancel,
              AppStrings.ledgerColCancel,
              divider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SequenceMark extends StatelessWidget {
  const _SequenceMark({required this.text, required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(text, style: style),
      ),
    );
  }
}

class _InputFigure extends StatelessWidget {
  const _InputFigure(this.value, this.style);

  final MoneyValue? value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (value != null && value!.isInvalid) {
      return MoneyText(MoneyValue.invalidLabel, style: style);
    }
    final text = value == null || !value!.isValid
        ? AppStrings.dash
        : '${value!.units}';
    return LtrText(text, style: style);
  }
}

class _FactorFigure extends StatelessWidget {
  const _FactorFigure(this.value, this.money, this.style);

  final MoneyValue value;
  final MoneyFormatter money;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (value.isInvalid || value.units == null) {
      return MoneyText(MoneyValue.invalidLabel, style: style);
    }
    return LtrText(money.formatScaled(value.units!, 6), style: style);
  }
}

/// The owner's name in a pill at the top of the ledger.
class _OwnerPill extends StatelessWidget {
  const _OwnerPill({required this.name, required this.section});

  final String name;
  final String section;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return Semantics(
      label: '$section: $name',
      child: DecoratedBox(
        key: const Key('ledger-owner-pill'),
        decoration: BoxDecoration(
          color: look.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: look.accent.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  key: const Key('ledger-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(15, 800, color: look.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small round frame for the bar's icon buttons.
class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: look.card,
        border: Border.all(color: look.cardBorder),
      ),
      child: SizedBox.square(dimension: 48, child: Center(child: child)),
    );
  }
}

/// بواسطة: who recorded the row, as a small outlined chip.
class _ByChip extends StatelessWidget {
  const _ByChip(this.name, {required this.reversed});

  final String name;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: look.accent.withValues(alpha: 0.5)),
        color: look.accent.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: cairo(
            10.5,
            700,
            color: look.ink,
          ).copyWith(decoration: reversed ? TextDecoration.lineThrough : null),
        ),
      ),
    );
  }
}
