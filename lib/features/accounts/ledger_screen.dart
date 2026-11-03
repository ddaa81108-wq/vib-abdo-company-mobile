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
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
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

  final _rows = ScrollController();
  final _innerRows = ScrollController();
  final _columnsScroll = ScrollController();

  AccountSection get section => widget.section;
  String get id => widget.id;

  @override
  void dispose() {
    _rows.dispose();
    _innerRows.dispose();
    _columnsScroll.dispose();
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
          final customers = section == AccountSection.customers;
          final bar = Row(
            children: [
              IconButton(
                tooltip: AppStrings.back,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/${section.path}'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _ledgerTitle(section),
                  key: const Key('ledger-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(18, 800, color: context.look.ink),
                ),
              ),
              EditAccountCardButton(
                section: section,
                card: loadedCard,
                compact: true,
              ),
            ],
          );
          final pinned = Padding(
            padding: padding.copyWith(top: AppSpacing.xs, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar,
                const SizedBox(height: AppSpacing.xs),
                if (customers)
                  _TotalCard(
                    card: loadedCard,
                    money: money,
                    awaitingServerBalance: _balanceAwaitingReload,
                    ackBalance: _ackBalance,
                    reloadError: reloadError,
                  )
                else
                  _Header(
                    section: section,
                    card: loadedCard,
                    money: money,
                    title: _ledgerTitle(section),
                    awaitingServerBalance: _balanceAwaitingReload,
                    ackBalance: _ackBalance,
                    reloadError: reloadError,
                    showTitle: false,
                  ),
              ],
            ),
          );
          // At large text the pinned card may be taller than a small
          // screen. It then scrolls inside its own band.
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxPinned = constraints.maxHeight.isFinite
                  ? constraints.maxHeight * 0.42
                  : MediaQuery.sizeOf(context).height * 0.42;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxPinned),
                    child: SingleChildScrollView(
                      key: const Key('ledger-pinned'),
                      child: pinned,
                    ),
                  ),
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
    final showBalance = page.page.items.any(
      (entry) => entry.balanceAfterUnits != null,
    );
    HistoryWindowTrace.ledgerPage = [
      for (final entry in page.page.items) entry.id,
    ];
    // Like the website: cancelled (reversed) rows are not drawn. The server
    // keeps them for the audit trail.
    final rows = _oldestFirst(page.page.items.where(websiteShowsRow).toList());
    final cardReady = _cardReadyForWrite(card);
    final composer = canWrite
        ? _InlineComposer(
            key: const Key('ledger-composer'),
            section: section,
            accountId: id,
            cardReady: cardReady,
            online: online,
            cardVersion: card.asData?.value.version,
            onPosted: _posted,
            onFull: (meta) => _full(context, ref, meta),
          )
        : null;
    final columns = _LedgerColumns(showBalance: showBalance);
    Widget row(LedgerEntryDto entry) => _EntryTile(
      key: ValueKey('ledger-row-${entry.id}'),
      section: section,
      accountId: id,
      entry: entry,
      money: money,
      columns: columns,
      canWrite: canWrite,
      editing: _editingId == entry.id,
      onEdit: () => _openInlineEdit(entry.id),
      onEditDone: _closeInlineEdit,
      onCancel: (meta) => _cancel(context, ref, entry, meta),
    );
    final resetKey = '${section.path}/$id/${identityHashCode(page)}';
    if (_openedAtBottomFor != resetKey) {
      _openedAtBottomFor = resetKey;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEntry());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth - padding.horizontal;
        final table = <Widget>[
          _LedgerColumnHeader(columns: columns),
          if (page.page.nextCursor != null)
            _LoadOlderLedger(
              key: ObjectKey(page),
              section: section,
              id: id,
              cursor: page.page.nextCursor!,
              row: row,
            ),
          if (rows.length <= HistoryWindow.eagerLimit)
            for (final entry in rows) row(entry)
          else
            SizedBox(
              height: 560,
              child: ListView.builder(
                key: const Key('ledger-entries-list'),
                controller: _innerRows,
                itemCount: rows.length,
                itemBuilder: (context, index) => row(rows[index]),
              ),
            ),
        ];
        return RefreshIndicator(
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
            padding: padding.copyWith(top: AppSpacing.sm),
            children: [
              _LedgerTable(
                controller: _columnsScroll,
                width: columns.width,
                viewport: viewport,
                footnote: showBalance ? null : AppStrings.statementHidden,
                composer: composer,
                children: page.page.items.isEmpty
                    ? const [EmptyPane(message: AppStrings.emptyLedger)]
                    : table,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  /// First open: the newest rows and the entry buttons are on screen.
  void _jumpToEntry() {
    if (!mounted) return;
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

class _MovementForm extends ConsumerStatefulWidget {
  const _MovementForm({
    required this.section,
    required this.id,
    required this.type,
    this.onSaved,
    super.key,
  });

  final AccountSection section;
  final String id;
  final String type;

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
              child: Text(AppStrings.divide),
            ),
            DropdownMenuItem(
              value: CalculationMode.multiply,
              child: Text(AppStrings.multiply),
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

  /// The website's add row: البيان، القيمة، السعر، العملية، التاريخ، حفظ.
  /// Same fields, checks, and request as the sheet.
  Widget _inline(BuildContext context, AsyncValue<AccountCardDto> watchedCard) {
    final look = context.look;
    final tight = layoutIsTight(context);
    final note = TextField(
      key: const Key('movement-note'),
      controller: _note,
      decoration: const InputDecoration(
        labelText: AppStrings.ledgerColNote,
        isDense: true,
      ),
    );
    final amount = UnitsField(
      key: const Key('movement-amount'),
      controller: _amount,
      label: AppStrings.ledgerColValue,
      dense: true,
      showHint: false,
    );
    final rate = TextField(
      key: const Key('movement-factor'),
      controller: _factor,
      enabled: _mode != CalculationMode.direct,
      textDirection: TextDirection.ltr,
      decoration: const InputDecoration(
        labelText: AppStrings.ledgerColRate,
        isDense: true,
      ),
    );
    final date = TextField(
      key: const Key('movement-date'),
      controller: _date,
      textDirection: TextDirection.ltr,
      decoration: const InputDecoration(
        labelText: AppStrings.date,
        isDense: true,
        prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
      ),
    );
    final modes = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          AppStrings.ledgerColOperation,
          style: cairo(12, 700, color: look.muted),
        ),
        for (final mode in const [
          CalculationMode.direct,
          CalculationMode.divide,
          CalculationMode.multiply,
        ])
          ChoiceChip(
            key: Key('movement-mode-${mode.name}'),
            label: Text(calculationLabel(mode)),
            selected: _mode == mode,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setState(() => _mode = mode),
          ),
      ],
    );
    final save = GuardedMutation(
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
    );
    const gap = SizedBox(width: AppSpacing.sm, height: AppSpacing.sm);
    return Column(
      key: const Key('movement-inline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tight) ...[
          note,
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: amount),
              gap,
              Expanded(child: rate),
            ],
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: note),
              gap,
              Expanded(flex: 2, child: amount),
              gap,
              Expanded(flex: 2, child: rate),
            ],
          ),
        gap,
        modes,
        gap,
        if (tight) ...[
          date,
          gap,
          save,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: date),
              gap,
              save,
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.unitsHint, style: cairo(11, 500, color: look.muted)),
        Text(AppStrings.noPreview, style: cairo(11, 500, color: look.muted)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showTitle)
                    Text(title, style: cairo(16, 800, color: foreground)),
                  if (visual.label != null)
                    Text(visual.label!, style: cairo(12, 700, color: accent)),
                ],
              ),
              Text(value.name, style: cairo(18, 800, color: foreground)),
              if (value.phone != null)
                LtrText(value.phone!, style: cairo(12, 500, color: accent)),
              if (kindWord != null)
                Text(
                  AppStrings.ledgerTotal,
                  style: cairo(12, 600, color: accent),
                ),
              Wrap(
                spacing: AppSpacing.sm,
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
    required this.card,
    required this.money,
    this.awaitingServerBalance = false,
    this.ackBalance,
    this.reloadError,
  });

  final AccountCardDto card;
  final MoneyFormatter money;
  final bool awaitingServerBalance;
  final MoneyValue? ackBalance;
  final String? reloadError;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final shown = awaitingServerBalance ? ackBalance : card.balanceUnits;
    final kind = customerBalanceKind(shown);
    final gloss = switch (kind) {
      CustomerBalanceKind.debt => look.glossDebt,
      CustomerBalanceKind.credit => look.glossCredit,
      CustomerBalanceKind.zero => look.glossZero,
      CustomerBalanceKind.unknown => look.glossGrey,
    };
    final word = switch (kind) {
      CustomerBalanceKind.debt => AppStrings.customerDebtWord,
      CustomerBalanceKind.credit => AppStrings.customerCreditWord,
      CustomerBalanceKind.zero => AppStrings.ledgerZeroWord,
      CustomerBalanceKind.unknown => null,
    };
    final units = shown?.asInt;
    final text = kind == CustomerBalanceKind.credit && units != null
        ? money.format(-units, card.currency)
        : money.formatOrDash(shown, card.currency);
    final radius = BorderRadius.circular(AppRadii.card);
    final subtitle = [
      card.name,
      if (card.phone != null && card.phone!.isNotEmpty) card.phone!,
    ].join(' • ');
    final age = card.ageStatusLabel;
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
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.ledgerTotal,
                        style: cairo(12, 700, color: gloss.ink),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: MoneyText(
                          text,
                          key: const Key('ledger-header-balance'),
                          style: context.textExtras.amountLarge.copyWith(
                            color: gloss.amount,
                          ),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: cairo(
                          12,
                          600,
                          color: gloss.ink.withValues(alpha: 0.85),
                        ),
                      ),
                      if (age != null && age.isNotEmpty)
                        Text(
                          age,
                          style: cairo(
                            11.5,
                            600,
                            color: gloss.ink.withValues(alpha: 0.8),
                          ),
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
                          key: ValueKey(
                            'system-${card.systemLinkKey ?? 'managed'}',
                          ),
                          style: cairo(12, 700, color: gloss.ink),
                        ),
                    ],
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
                        vertical: AppSpacing.xs,
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
          ),
        ),
      ),
    );
  }
}

class _LoadOlderLedger extends ConsumerStatefulWidget {
  const _LoadOlderLedger({
    super.key,
    required this.section,
    required this.id,
    required this.cursor,
    required this.row,
  });

  final AccountSection section;
  final String id;
  final String cursor;

  /// Builds one table row, the same as the newest page uses.
  final Widget Function(LedgerEntryDto entry) row;

  @override
  ConsumerState<_LoadOlderLedger> createState() => _LoadOlderLedgerState();
}

class _LoadOlderLedgerState extends ConsumerState<_LoadOlderLedger> {
  final _extra = <LedgerEntryDto>[];
  String? _cursor;
  String? _error;
  var _busy = false;

  /// The newest prefix is full and the next load should show the page that
  /// was just dropped, without opening a gap in front of it.
  var _replay = false;

  /// The user already reloaded a dropped page, so later pages stay attached
  /// to that newest prefix.
  var _extend = false;
  var _scrollArmed = true;

  /// First page is already on screen. Each successful load-more adds one.
  var _pagesLoaded = 1;

  @override
  void initState() {
    super.initState();
    _cursor = widget.cursor;
  }

  Future<void> _load() async {
    final cursor = _cursor;
    if (cursor == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(apiLayerProvider)
          .accounts
          .ledger(widget.section, widget.id, before: cursor);
      if (!mounted) return;
      setState(() {
        _applyPage(page);
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureText(ref.read(errorHandlerProvider).toFailure(error));
      });
    }
  }

  /// Newest rows stay. Overflow drops the oldest extras and remembers the
  /// boundary so the next load can show that page again (DEF-027).
  void _applyPage(LedgerPage page) {
    final incoming = page.page.items;
    if (!HistoryWindow.trimEnabled || _extend) {
      _addFresh(incoming);
      _cursor = page.page.nextCursor;
      _pagesLoaded++;
      return;
    }
    if (_replay) {
      _addFresh(incoming);
      _cursor = page.page.nextCursor;
      _replay = false;
      _extend = true;
      _pagesLoaded++;
      return;
    }
    _extra.addAll(incoming);
    if (_extra.length > HistoryWindow.retainLimit) {
      final boundary = _extra[HistoryWindow.retainLimit - 1];
      _extra.removeRange(HistoryWindow.retainLimit, _extra.length);
      _cursor = boundary.id;
      _replay = true;
    } else {
      _cursor = page.page.nextCursor;
    }
    _pagesLoaded++;
  }

  void _addFresh(List<LedgerEntryDto> incoming) {
    final known = {for (final entry in _extra) entry.id};
    for (final entry in incoming) {
      if (known.add(entry.id)) _extra.add(entry);
    }
  }

  bool _onOlderScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent > 0 &&
        metrics.pixels < metrics.maxScrollExtent - 24) {
      _scrollArmed = true;
      return false;
    }
    if (!historyDraggedToEnd(notification)) return false;
    if (!_scrollArmed || _cursor == null || _busy) return false;
    _scrollArmed = false;
    _load();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    HistoryWindowTrace.ledgerExtra = [for (final entry in _extra) entry.id];
    final scheme = Theme.of(context).colorScheme;
    // Older rows sit above the newest page, oldest first.
    final shown = _oldestFirst(_extra.where(websiteShowsRow).toList());
    final older = shown.length <= HistoryWindow.eagerLimit
        ? <Widget>[for (final entry in shown) widget.row(entry)]
        : <Widget>[
            SizedBox(
              height: 560,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onOlderScroll,
                child: ListView.builder(
                  key: const Key('ledger-older-list'),
                  itemCount: shown.length,
                  itemBuilder: (context, index) => widget.row(shown[index]),
                ),
              ),
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: Key('ledger-pages-$_pagesLoaded'),
          child: const SizedBox.shrink(),
        ),
        KeyedSubtree(
          key: Key('ledger-retained-${_extra.length}'),
          child: const SizedBox.shrink(),
        ),
        if (_cursor != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('load-older'),
              onPressed: _busy ? null : _load,
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : Text(
                      _error == null ? AppStrings.loadOlder : AppStrings.retry,
                    ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(
              _error!,
              key: const Key('load-older-error'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.error),
            ),
          ),
        ...older,
      ],
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
  const _LedgerColumns({required this.showBalance});

  final bool showBalance;

  static const seq = 34.0;
  static const when = 98.0;
  static const type = 82.0;
  static const note = 112.0;
  static const value = 72.0;
  static const operation = 58.0;
  static const rate = 58.0;
  static const debt = 88.0;
  static const paid = 88.0;
  static const balance = 88.0;
  static const edit = 48.0;
  static const cancel = 48.0;

  double get width =>
      seq +
      when +
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
    this.footnote,
  });

  final ScrollController controller;
  final double width;
  final double viewport;
  final List<Widget> children;
  final Widget? composer;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final radius = BorderRadius.circular(AppRadii.card);
    final tableWidth = width > viewport ? width : viewport;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: const Key('ledger-table'),
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: radius,
        border: Border.all(color: look.cardBorder),
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
                    children: children,
                  ),
                ),
              ),
            ),
            Container(
              color: look.strip,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      footnote ?? '',
                      style: cairo(10.5, 500, color: look.muted),
                    ),
                  ),
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
            if (composer != null) ...[
              Divider(height: 1, color: look.cardBorder),
              composer!,
            ],
          ],
        ),
      ),
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

class _Cell extends StatelessWidget {
  const _Cell(this.width, this.child, {this.alignment});

  final double width;
  final Widget child;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
    super.key,
  });

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
    final sequence = entry.sequence == null
        ? AppStrings.dash
        : '${entry.sequence}';
    final date = entry.date;
    final isPayment = entry.type == 'payment';
    final amountColor = _movementAmountColor(
      context,
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
        _LedgerColumns.type,
        _TypeChip(
          label: movementLabel(
            section: section,
            type: entry.type,
            paymentMode: entry.paymentMode,
          ),
          kind: _chipKind(entry),
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
            if (entry.createdByName != null)
              Text(
                entry.createdByName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small,
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
        _Fit(Text(calculationLabel(entry.calculationMode), style: body)),
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
          entry.balanceAfterUnits == null
              ? dash
              : _Fit(
                  MoneyText(
                    money.formatOrDash(
                      entry.balanceAfterUnits,
                      section.currency,
                    ),
                    key: Key('ledger-balance-${entry.id}'),
                    style: number.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
        ),
      _Cell(_LedgerColumns.edit, correct),
      _Cell(_LedgerColumns.cancel, cancel),
    ];
    final viewport = _InlineViewport.of(context);
    // Zebra by the server sequence, so older pages stripe the same way.
    final odd = (entry.sequence ?? 0).isOdd;
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
            border: Border(bottom: BorderSide(color: look.cardBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: cells,
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
_ChipKind _chipKind(LedgerEntryDto entry) {
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
    super.key,
  });

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
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
        ),
        onPressed: enabled ? () => setState(() => _type = type) : null,
        child: Text(label, style: cairo(13, 800)),
      );
    }

    final chips = widget.cardReady
        ? Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              chip(
                const Key('add-debt'),
                _deposits
                    ? (widget.section == AccountSection.libyanDeposits
                          ? AppStrings.depositIn
                          : AppStrings.egpIn)
                    : AppStrings.debtMovement,
                'debt',
                _ChipKind.debt,
              ),
              chip(
                const Key('add-payment'),
                _deposits
                    ? (widget.section == AccountSection.libyanDeposits
                          ? AppStrings.depositOut
                          : AppStrings.egpOut)
                    : AppStrings.paymentMovement,
                'payment',
                _ChipKind.partial,
              ),
              if (!_deposits)
                chip(
                  const Key('composer-full'),
                  AppStrings.fullPayment,
                  'full',
                  _ChipKind.full,
                ),
            ],
          )
        : const SizedBox.shrink();
    final Widget body;
    if (_type == 'full' && !_deposits) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.fullPaymentHint,
              style: cairo(12, 500, color: look.muted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GuardedMutation(
            buttonKey: const Key('full-payment'),
            allowed: widget.cardReady,
            inputs: 'full:${widget.cardVersion}',
            expectedVersion: widget.cardVersion,
            label: AppStrings.save,
            onSubmit: widget.onFull,
          ),
        ],
      );
    } else {
      body = _MovementForm(
        key: ValueKey('movement-$_type-$_round'),
        section: widget.section,
        id: widget.accountId,
        type: _type,
        onSaved: (posted) {
          setState(() => _round++);
          widget.onPosted(posted);
        },
      );
    }
    return Container(
      color: look.strip.withValues(alpha: 0.6),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: look.accent),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  AppStrings.ledgerAddMovement,
                  style: cairo(14, 800, color: look.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          chips,
          const SizedBox(height: AppSpacing.sm),
          body,
        ],
      ),
    );
  }
}

/// Debt lines use [AppStatusColors.debtText]. Payment lines use
/// [AppStatusColors.creditText]. Other types stay on the surface colour.
Color _movementAmountColor(BuildContext context, String type, Color fallback) {
  final colors = context.statusColors;
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
    Widget head(double width, String text) =>
        _Cell(width, Text(text, style: style, textAlign: TextAlign.center));
    return DecoratedBox(
      key: const Key('ledger-column-header'),
      decoration: BoxDecoration(
        color: look.strip,
        border: Border(bottom: BorderSide(color: look.cardBorder)),
      ),
      child: Row(
        children: [
          head(_LedgerColumns.seq, AppStrings.ledgerColSeq),
          head(_LedgerColumns.when, AppStrings.ledgerColWhen),
          head(_LedgerColumns.type, AppStrings.ledgerColType),
          head(_LedgerColumns.note, AppStrings.ledgerColNote),
          head(_LedgerColumns.value, AppStrings.ledgerColValue),
          head(_LedgerColumns.operation, AppStrings.ledgerColOperation),
          head(_LedgerColumns.rate, AppStrings.ledgerColRate),
          head(_LedgerColumns.debt, AppStrings.ledgerColDebt),
          head(_LedgerColumns.paid, AppStrings.ledgerColPaid),
          if (columns.showBalance)
            head(_LedgerColumns.balance, AppStrings.ledgerColBalance),
          head(_LedgerColumns.edit, AppStrings.ledgerColEdit),
          head(_LedgerColumns.cancel, AppStrings.ledgerColCancel),
        ],
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
