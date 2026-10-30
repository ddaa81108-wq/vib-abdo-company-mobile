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
import 'edit_account_card_screen.dart';
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

  AccountSection get section => widget.section;
  String get id => widget.id;

  @override
  void didUpdateWidget(LedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section || oldWidget.id != widget.id) {
      _balanceAwaitingReload = false;
      _ackBalance = null;
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
          return KeptData<LedgerPage>(
            value: ledger,
            resetKey: '${section.path}/$id/ledger',
            expand: true,
            onRetry: () => ref.invalidate(ledgerProvider((section, id))),
            messageOf: messageOf,
            failureOf: failureOf,
            loading: const _LedgerLoading(),
            builder: (page) {
              final showBalance = page.page.items.any(
                (entry) => entry.balanceAfterUnits != null,
              );
              HistoryWindowTrace.ledgerPage = [
                for (final entry in page.page.items) entry.id,
              ];
              final tight = layoutIsTight(context);
              final cardReady = _cardReadyForWrite(card);
              final writes = <Widget>[
                GatedButton(
                  buttonKey: const Key('add-debt'),
                  allowed: cardReady,
                  online: online,
                  label: section == AccountSection.libyanDeposits
                      ? AppStrings.depositIn
                      : section == AccountSection.egyptianDeposits
                      ? AppStrings.egpIn
                      : AppStrings.debtMovement,
                  onPressed: () => _movement(context, ref, type: 'debt'),
                ),
                GatedButton(
                  buttonKey: const Key('add-payment'),
                  allowed: cardReady,
                  online: online,
                  label: section == AccountSection.libyanDeposits
                      ? AppStrings.depositOut
                      : section == AccountSection.egyptianDeposits
                      ? AppStrings.egpOut
                      : AppStrings.paymentMovement,
                  onPressed: () => _movement(context, ref, type: 'payment'),
                ),
                GuardedMutation(
                  buttonKey: const Key('full-payment'),
                  allowed:
                      cardReady &&
                      section != AccountSection.libyanDeposits &&
                      section != AccountSection.egyptianDeposits,
                  filled: false,
                  inputs: 'full:${card.asData?.value.version}',
                  expectedVersion: card.asData?.value.version,
                  label: AppStrings.fullPayment,
                  onSubmit: (meta) => _full(context, ref, meta),
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: pagePadding(MediaQuery.sizeOf(context).width)
                      .copyWith(top: AppSpacing.sm),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: AppStrings.back,
                          onPressed: () => context.go('/${section.path}'),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: _Header(
                            section: section,
                            card: loadedCard,
                            money: money,
                            title: _ledgerTitle(section),
                            awaitingServerBalance: _balanceAwaitingReload,
                            ackBalance: _ackBalance,
                            reloadError: reloadError,
                          ),
                        ),
                      ],
                    ),
                    EditAccountCardButton(section: section, card: loadedCard),
                    if (canWrite) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _ActionRow(children: writes),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.noPreview,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!showBalance)
                      Text(
                        AppStrings.statementHidden,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    if (page.page.items.isEmpty)
                      const EmptyPane(message: AppStrings.emptyLedger)
                    else if (page.page.items.length <=
                        HistoryWindow.eagerLimit) ...[
                      if (!tight) _LedgerColumnHeader(showBalance: showBalance),
                      for (final entry in page.page.items)
                        _EntryTile(
                          section: section,
                          accountId: id,
                          entry: entry,
                          money: money,
                          showBalance: showBalance,
                          canWrite: canWrite,
                          onCancel: (meta) =>
                              _cancel(context, ref, entry, meta),
                        ),
                    ] else ...[
                      if (!tight) _LedgerColumnHeader(showBalance: showBalance),
                      SizedBox(
                        height: 560,
                        child: ListView.builder(
                          key: const Key('ledger-entries-list'),
                          itemCount: page.page.items.length,
                          itemBuilder: (context, index) {
                            final entry = page.page.items[index];
                            return _EntryTile(
                              section: section,
                              accountId: id,
                              entry: entry,
                              money: money,
                              showBalance: showBalance,
                              canWrite: canWrite,
                              onCancel: (meta) =>
                                  _cancel(context, ref, entry, meta),
                            );
                          },
                        ),
                      ),
                    ],
                    if (page.page.nextCursor != null)
                      _LoadOlderLedger(
                        key: ObjectKey(page),
                        section: section,
                        id: id,
                        cursor: page.page.nextCursor!,
                        money: money,
                        showBalance: showBalance,
                        canWrite: canWrite,
                        onCancel: (entry, meta) =>
                            _cancel(context, ref, entry, meta),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _movement(
    BuildContext context,
    WidgetRef ref, {
    required String type,
  }) async {
    final saved = await showAppForm<PostedMovement>(
      context,
      _MovementForm(section: section, id: id, type: type),
    );
    if (saved != null) {
      setState(() {
        _balanceAwaitingReload = true;
        _ackBalance = saved.balanceUnits;
      });
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountCardProvider((section, id)));
      ref.invalidate(accountsProvider(section));
      ref.invalidate(homeDashboardProvider);
    }
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
  });

  final AccountSection section;
  final String id;
  final String type;

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
            label: AppStrings.ledgerReloadFailed,
            child: const Text(
              AppStrings.ledgerReloadFailed,
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
      Navigator.of(context).pop(PostedMovement(balanceUnits: ack.balanceUnits));
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
  });

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
                  Text(title, style: cairo(16, 800, color: foreground)),
                  if (visual.label != null)
                    Text(visual.label!, style: cairo(12, 700, color: accent)),
                ],
              ),
              Text(value.name, style: cairo(18, 800, color: foreground)),
              if (value.phone != null)
                LtrText(value.phone!, style: cairo(12, 500, color: accent)),
              MoneyText(
                money.formatOrDash(shownBalance, value.currency),
                key: const Key('ledger-header-balance'),
                style: context.textExtras.amountLarge.copyWith(
                  color: balanceColor,
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

class _LoadOlderLedger extends ConsumerStatefulWidget {
  const _LoadOlderLedger({
    super.key,
    required this.section,
    required this.id,
    required this.cursor,
    required this.money,
    required this.showBalance,
    required this.canWrite,
    required this.onCancel,
  });

  final AccountSection section;
  final String id;
  final String cursor;
  final MoneyFormatter money;
  final bool showBalance;
  final bool canWrite;
  final Future<String?> Function(LedgerEntryDto entry, MutationMeta meta)
  onCancel;

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
    final older = _extra.length <= HistoryWindow.eagerLimit
        ? <Widget>[
            for (final entry in _extra)
              _EntryTile(
                section: widget.section,
                accountId: widget.id,
                entry: entry,
                money: widget.money,
                showBalance: widget.showBalance,
                canWrite: widget.canWrite,
                onCancel: (meta) => widget.onCancel(entry, meta),
              ),
          ]
        : <Widget>[
            SizedBox(
              height: 560,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onOlderScroll,
                child: ListView.builder(
                  key: const Key('ledger-older-list'),
                  itemCount: _extra.length,
                  itemBuilder: (context, index) {
                    final entry = _extra[index];
                    return _EntryTile(
                      section: widget.section,
                      accountId: widget.id,
                      entry: entry,
                      money: widget.money,
                      showBalance: widget.showBalance,
                      canWrite: widget.canWrite,
                      onCancel: (meta) => widget.onCancel(entry, meta),
                    );
                  },
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
        ...older,
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
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.section,
    required this.accountId,
    required this.entry,
    required this.money,
    required this.showBalance,
    required this.canWrite,
    required this.onCancel,
  });

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;
  final MoneyFormatter money;
  final bool showBalance;
  final bool canWrite;
  final Future<String?> Function(MutationMeta meta) onCancel;

  @override
  Widget build(BuildContext context) {
    final reversed = entry.status == 'reversed';
    final scheme = Theme.of(context).colorScheme;
    final muted = reversed ? scheme.onSurfaceVariant : scheme.onSurface;
    final strike = reversed ? TextDecoration.lineThrough : null;
    final body = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: muted, decoration: strike);
    final tight = layoutIsTight(context);
    final sequence = entry.sequence == null
        ? AppStrings.dash
        : '${entry.sequence}';
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SequenceMark(
              key: Key('ledger-sequence-${entry.id}'),
              text: sequence,
              style: context.textExtras.tableNumber.copyWith(
                color: muted,
                decoration: strike,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                movementLabel(
                  section: section,
                  type: entry.type,
                  paymentMode: entry.paymentMode,
                ),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: muted, decoration: strike),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LtrText(
            formatIsoDate(entry.date),
            key: Key('ledger-date-${entry.id}'),
            style: context.textExtras.tableNumber.copyWith(
              color: muted,
              decoration: strike,
            ),
          ),
        ),
      ],
    );
    final figures = _AmountBlock(
      entry: entry,
      section: section,
      money: money,
      showBalance: showBalance,
      reversed: reversed,
    );
    return Card(
      color: reversed ? scheme.surfaceContainerHighest : null,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tight) ...[
              identity,
              const SizedBox(height: AppSpacing.sm),
              figures,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 2, child: figures),
                ],
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(calculationLabel(entry.calculationMode), style: body),
                Text(AppStrings.inputValue, style: body),
                _InputFigure(entry.inputValue, body),
                if (entry.factorMicros != null) ...[
                  Text(AppStrings.factor, style: body),
                  _FactorFigure(entry.factorMicros!, money, body),
                ],
              ],
            ),
            if (entry.note != null) Text(entry.note!, style: body),
            if (entry.createdByName != null)
              Text('${AppStrings.actor}: ${entry.createdByName}', style: body),
            LtrText(entry.id, style: body),
            if (reversed)
              Text(
                AppStrings.reversed,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (entry.corrected)
              Text(
                AppStrings.corrected,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            _EntryActions(
              section: section,
              accountId: accountId,
              entry: entry,
              canCancel: canWrite && !reversed,
              onCancel: onCancel,
            ),
          ],
        ),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(key: Key('ledger-loading'), height: 112),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 84),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 84),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final child in children)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _LedgerColumnHeader extends StatelessWidget {
  const _LedgerColumnHeader({required this.showBalance});

  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final amount = showBalance
        ? '${AppStrings.amount} · ${AppStrings.balanceAfter}'
        : AppStrings.amount;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '${AppStrings.sequence} · ${AppStrings.date}',
              style: style,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(amount, style: style, textAlign: TextAlign.end),
            ),
          ),
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

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.entry,
    required this.section,
    required this.money,
    required this.showBalance,
    required this.reversed,
  });

  final LedgerEntryDto entry;
  final AccountSection section;
  final MoneyFormatter money;
  final bool showBalance;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strike = reversed ? TextDecoration.lineThrough : null;
    final amountColor = _movementAmountColor(
      context,
      entry.type,
      reversed ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoneyText(
            money.formatOrDash(entry.amountUnits, section.currency),
            key: Key('ledger-amount-${entry.id}'),
            style: context.textExtras.amount.copyWith(
              color: amountColor,
              decoration: strike,
            ),
          ),
          if (showBalance && entry.balanceAfterUnits != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            MoneyText(
              money.formatOrDash(entry.balanceAfterUnits, section.currency),
              key: Key('ledger-balance-${entry.id}'),
              style: context.textExtras.tableNumber.copyWith(
                color: scheme.onSurface,
                decoration: strike,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryActions extends StatelessWidget {
  const _EntryActions({
    required this.section,
    required this.accountId,
    required this.entry,
    required this.canCancel,
    required this.onCancel,
  });

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;
  final bool canCancel;
  final Future<String?> Function(MutationMeta meta) onCancel;

  @override
  Widget build(BuildContext context) {
    final cancel = canCancel
        ? GuardedMutation(
            buttonKey: Key('cancel-${entry.id}'),
            inputs: 'cancel:${entry.id}:${entry.version}',
            expectedVersion: entry.version,
            filled: false,
            label: AppStrings.cancelMovement,
            confirmText: AppStrings.confirmCancel,
            onSubmit: onCancel,
          )
        : null;
    final correct = TransactionCorrectionLauncher(
      section: section,
      accountId: accountId,
      entry: entry,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final child in [?cancel, correct])
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: child,
              ),
          ],
        );
      },
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
