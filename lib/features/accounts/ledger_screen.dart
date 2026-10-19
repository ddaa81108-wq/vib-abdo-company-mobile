import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Ledger for one card. Customers, companies, Libyan deposits, and Egyptian
/// deposits all use this screen; [section] selects the repository and the labels.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({required this.section, required this.id, super.key});

  final AccountSection section;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(section.sectionKey)) return const ForbiddenPane();
    final ledger = ref.watch(ledgerProvider((section, id)));
    final card = ref.watch(accountCardProvider((section, id)));
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    // Writes stay hidden until the card has loaded and is not system-managed.
    final loadedCard = card.asData?.value;
    final canWrite = loadedCard != null &&
        !loadedCard.systemManaged &&
        permissions.canWrite(section.sectionKey);

    if (card.hasError) {
      return Scaffold(
        key: Key('screen-ledger-${section.path}'),
        body: ErrorPane(
          message: ref.read(errorHandlerProvider).toFailure(card.error!).message,
          onRetry: () {
            ref.invalidate(accountCardProvider((section, id)));
            ref.invalidate(ledgerProvider((section, id)));
          },
        ),
      );
    }

    return Scaffold(
      key: Key('screen-ledger-${section.path}'),
      body: ledger.when(
        loading: () => const SkeletonBox(key: Key('ledger-loading'), height: 240),
        error: (error, _) => ErrorPane(
          message: ref.read(errorHandlerProvider).toFailure(error).message,
          onRetry: () => ref.invalidate(ledgerProvider((section, id))),
        ),
        data: (page) {
          final showBalance = page.page.items.any((entry) => entry.balanceAfterUnits != null);
          return ListView(
            padding: pagePadding(MediaQuery.sizeOf(context).width),
            children: [
              Row(
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
                    ),
                  ),
                ],
              ),
              if (canWrite)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    GatedButton(
                      buttonKey: const Key('add-debt'),
                      allowed: true,
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
                      allowed: true,
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
                      allowed: section != AccountSection.libyanDeposits &&
                          section != AccountSection.egyptianDeposits,
                      online: online,
                      filled: false,
                      inputs: 'full:${card.asData?.value.version}',
                      expectedVersion: card.asData?.value.version,
                      label: AppStrings.fullPayment,
                      onSubmit: (meta) => _full(context, ref, meta),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              const Text(AppStrings.noPreview),
              if (!showBalance)
                Text(
                  AppStrings.statementHidden,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              if (page.page.items.isEmpty)
                const EmptyPane(message: AppStrings.emptyLedger)
              else
                for (final entry in page.page.items)
                  _EntryTile(
                    section: section,
                    entry: entry,
                    money: money,
                    showBalance: showBalance,
                    canWrite: canWrite,
                    online: online,
                    onCancel: (meta) => _cancel(context, ref, entry, meta),
                  ),
              if (page.page.nextCursor != null)
                _LoadOlderLedger(
                  section: section,
                  id: id,
                  cursor: page.page.nextCursor!,
                  money: money,
                  showBalance: showBalance,
                  canWrite: canWrite,
                  online: online,
                  onCancel: (entry, meta) => _cancel(context, ref, entry, meta),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _movement(BuildContext context, WidgetRef ref, {required String type}) async {
    final saved = await showAppForm<bool>(
      context,
      _MovementForm(section: section, id: id, type: type),
    );
    if (saved == true) {
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountCardProvider((section, id)));
      ref.invalidate(accountsProvider(section));
    }
  }

  Future<String?> _full(BuildContext context, WidgetRef ref, MutationMeta meta) async {
    try {
      final ack = await ref.read(apiLayerProvider).accounts.addTransaction(
        section,
        id,
        AccountTransactionRequest.fullPayment(date: DateTime.now()),
        meta,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(ledgerProvider((section, id)));
      ref.invalidate(accountsProvider(section));
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }

  Future<String?> _cancel(
    BuildContext context,
    WidgetRef ref,
    LedgerEntryDto entry,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref.read(apiLayerProvider).accounts.cancelTransaction(
        section,
        id,
        entry.id,
        meta,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(ledgerProvider((section, id)));
      return null;
    } catch (error) {
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (failure.code == 'VERSION_CONFLICT') {
        ref.invalidate(ledgerProvider((section, id)));
      }
      return failure.message;
    }
  }
}

class _MovementForm extends ConsumerStatefulWidget {
  const _MovementForm({required this.section, required this.id, required this.type});

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
  late final TextEditingController _date = TextEditingController(text: formatIsoDate(DateTime.now()));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.type == 'payment' ? AppStrings.paymentMovement : AppStrings.debtMovement,
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
            DropdownMenuItem(value: CalculationMode.direct, child: Text(AppStrings.direct)),
            DropdownMenuItem(value: CalculationMode.divide, child: Text(AppStrings.divide)),
            DropdownMenuItem(value: CalculationMode.multiply, child: Text(AppStrings.multiply)),
          ],
          onChanged: (value) => setState(() => _mode = value ?? CalculationMode.direct),
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
          inputs: '${widget.type}|$_mode|${_amount.text}|${_factor.text}|${_date.text}|${_note.text}',
          expectedVersion: ref.watch(accountCardProvider((widget.section, widget.id))).asData?.value.version,
          label: AppStrings.save,
          online: ref.watch(onlineProvider),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    if (units == null) return AppStrings.integerOnly;
    final parsedDate = DateTime.tryParse(_date.text);
    if (parsedDate == null) return AppStrings.integerOnly;
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
      final ack = await ref.read(apiLayerProvider).accounts.addTransaction(
        widget.section,
        widget.id,
        request,
        meta,
      );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      Navigator.of(context).pop(true);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.section, required this.card, required this.money});

  final AccountSection section;
  final AccountCardDto? card;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final value = card;
    if (value == null) return const SkeletonBox(height: 48);
    final visual = ageVisual(
      colors: context.statusColors,
      ageStatus: value.ageStatus,
      section: section,
      serverLabel: value.ageStatusLabel,
    );
    final link = value.resolvedSystemLink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.name, style: Theme.of(context).textTheme.titleLarge),
        if (value.phone != null) LtrText(value.phone!),
        MoneyText(
          money.formatOrDash(value.balanceUnits, value.currency),
          style: context.textExtras.amountLarge.copyWith(
            color: visual.colored ? null : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (visual.label != null) Text(visual.label!),
        if (value.systemManaged)
          Text(AppStrings.systemCard, key: ValueKey('system-${link ?? 'managed'}')),
      ],
    );
  }
}

class _LoadOlderLedger extends ConsumerStatefulWidget {
  const _LoadOlderLedger({
    required this.section,
    required this.id,
    required this.cursor,
    required this.money,
    required this.showBalance,
    required this.canWrite,
    required this.online,
    required this.onCancel,
  });

  final AccountSection section;
  final String id;
  final String cursor;
  final MoneyFormatter money;
  final bool showBalance;
  final bool canWrite;
  final bool online;
  final Future<String?> Function(LedgerEntryDto entry, MutationMeta meta) onCancel;

  @override
  ConsumerState<_LoadOlderLedger> createState() => _LoadOlderLedgerState();
}

class _LoadOlderLedgerState extends ConsumerState<_LoadOlderLedger> {
  final _extra = <LedgerEntryDto>[];
  String? _cursor;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _cursor = widget.cursor;
  }

  Future<void> _load() async {
    final cursor = _cursor;
    if (cursor == null || _busy) return;
    setState(() => _busy = true);
    try {
      final page = await ref.read(apiLayerProvider).accounts.ledger(
        widget.section,
        widget.id,
        before: cursor,
      );
      if (!mounted) return;
      setState(() {
        _extra.addAll(page.page.items);
        _cursor = page.page.nextCursor;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in _extra)
          _EntryTile(
            section: widget.section,
            entry: entry,
            money: widget.money,
            showBalance: widget.showBalance,
            canWrite: widget.canWrite,
            online: widget.online,
            onCancel: (meta) => widget.onCancel(entry, meta),
          ),
        if (_cursor != null)
          TextButton(
            key: const Key('load-older'),
            onPressed: _busy ? null : _load,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.loadOlder),
          ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.section,
    required this.entry,
    required this.money,
    required this.showBalance,
    required this.canWrite,
    required this.online,
    required this.onCancel,
  });

  final AccountSection section;
  final LedgerEntryDto entry;
  final MoneyFormatter money;
  final bool showBalance;
  final bool canWrite;
  final bool online;
  final Future<String?> Function(MutationMeta meta) onCancel;

  @override
  Widget build(BuildContext context) {
    final reversed = entry.status == 'reversed';
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: reversed ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      decoration: reversed ? TextDecoration.lineThrough : null,
    );
    return Card(
      color: reversed ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.sequence}', style: style),
            Text(formatIsoDate(entry.date), style: style),
            Text(
              movementLabel(section: section, type: entry.type, paymentMode: entry.paymentMode),
              style: style,
            ),
            MoneyText(
              money.formatOrDash(entry.amountUnits, section.currency),
              style: context.textExtras.amount.copyWith(
                decoration: reversed ? TextDecoration.lineThrough : null,
              ),
            ),
            Text(
              '${calculationLabel(entry.calculationMode)} · ${AppStrings.inputValue} ${entry.inputValue ?? AppStrings.dash}'
              '${entry.factorMicros == null ? '' : ' · ${money.formatScaled(entry.factorMicros!, 6)}'}',
              style: style,
            ),
            LtrText(entry.id, style: style),
            if (entry.note != null) Text(entry.note!, style: style),
            if (entry.createdByName != null)
              Text('${AppStrings.actor}: ${entry.createdByName}', style: style),
            if (reversed) Text(AppStrings.reversed, style: Theme.of(context).textTheme.labelLarge),
            if (entry.corrected) const Text(AppStrings.corrected),
            if (showBalance && entry.balanceAfterUnits != null)
              Text(
                '${AppStrings.balanceAfter} ${money.format(entry.balanceAfterUnits!, section.currency)}',
              ),
            if (canWrite && !reversed)
              GuardedMutation(
                buttonKey: Key('cancel-${entry.id}'),
                inputs: 'cancel:${entry.id}:${entry.version}',
                expectedVersion: entry.version,
                online: online,
                filled: false,
                label: AppStrings.cancelMovement,
                confirmText: AppStrings.confirmCancel,
                onSubmit: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}
