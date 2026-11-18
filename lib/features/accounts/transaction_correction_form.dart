import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';

/// Correction of one ledger line, from [AccountsRepository.correctTransaction].
///
/// The request is the same transaction body as a new movement. Nothing in the
/// client says the server also writes a reversing line, so the copy does not
/// claim that. Amounts and balances shown here are server fields; the result
/// of the correction is whatever the next fetch returns.
class TransactionCorrectionLauncher extends ConsumerWidget {
  const TransactionCorrectionLauncher({
    required this.section,
    required this.accountId,
    required this.entry,
    this.onOpen,
    this.compact = false,
    super.key,
  });

  /// A pencil in the ledger table's تعديل column.
  final bool compact;

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;

  /// When set, the button opens the same form inline in the ledger row
  /// instead of a sheet. Same request, endpoint, and confirmation.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entry.status == 'reversed' || entry.status == 'deleted') {
      return const SizedBox.shrink();
    }
    final permissions = permissionsOf(ref);
    final card = ref
        .watch(accountCardProvider((section, accountId)))
        .asData
        ?.value;
    // `correct` is the token this screen asks for. It is not a confirmed
    // permission code. When the line carries allowedActions, that list decides.
    // When the list is absent, fall back to section write on a non-system card.
    final recorded = entry.allowedActions;
    final visible = recorded != null
        ? permissions.canOnRecord(
            action: 'correct',
            allowedActions: recorded,
            section: section.sectionKey,
          )
        : card != null &&
              !card.systemManaged &&
              permissions.canWrite(section.sectionKey);
    if (!visible) return const SizedBox.shrink();

    final online = ref.watch(onlineProvider);
    if (compact) {
      return Tooltip(
        message: AppStrings.correctTransaction,
        child: TextButton(
          key: Key('correct-${entry.id}'),
          onPressed: online
              ? (onOpen ?? () => _open(context, ref, accountId))
              : null,
          child: const Icon(Icons.edit_outlined, size: 18),
        ),
      );
    }
    return GatedButton(
      buttonKey: Key('correct-${entry.id}'),
      allowed: true,
      online: online,
      filled: false,
      label: AppStrings.correctTransaction,
      onPressed: onOpen ?? () => _open(context, ref, accountId),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) async {
    final saved = await showAppForm<bool>(
      context,
      TransactionCorrectionForm(
        section: section,
        accountId: accountId,
        entry: entry,
      ),
    );
    if (!context.mounted || saved != true) return;
    _refresh(ref, accountId);
  }

  void _refresh(WidgetRef ref, String accountId) {
    ref.invalidate(ledgerProvider((section, accountId)));
    ref.invalidate(accountCardProvider((section, accountId)));
    ref.invalidate(accountsProvider(section));
  }
}

class TransactionCorrectionForm extends ConsumerStatefulWidget {
  const TransactionCorrectionForm({
    required this.section,
    required this.accountId,
    required this.entry,
    this.onDone,
    this.rowBuilder,
    super.key,
  });

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;

  /// Inline use: called with true after a saved correction, instead of
  /// popping the sheet. The caller refreshes the same providers.
  final ValueChanged<bool>? onDone;

  /// Presentation only: reuse the same controllers, guard and submit handler.
  final Widget Function(CorrectionRowFields fields)? rowBuilder;

  @override
  ConsumerState<TransactionCorrectionForm> createState() =>
      _TransactionCorrectionFormState();
}

class _TransactionCorrectionFormState
    extends ConsumerState<TransactionCorrectionForm> {
  late final TextEditingController _amount = TextEditingController(
    text: _amountText(widget.entry.inputValue),
  );
  final _factor = TextEditingController();
  final _note = TextEditingController();
  late final TextEditingController _date = TextEditingController(
    text: widget.entry.date == null ? '' : formatIsoDate(widget.entry.date),
  );
  late String _type = widget.entry.type == 'payment' ? 'payment' : 'debt';
  late var _mode = widget.entry.calculationMode ?? CalculationMode.direct;
  late PaymentMode _paymentMode;

  bool get _allowsFull =>
      widget.section != AccountSection.libyanDeposits &&
      widget.section != AccountSection.egyptianDeposits;

  bool get _full =>
      _allowsFull && _type == 'payment' && _paymentMode == PaymentMode.full;

  @override
  void initState() {
    super.initState();
    _paymentMode = widget.entry.paymentMode == 'full' && _allowsFull
        ? PaymentMode.full
        : PaymentMode.partial;
    _note.text = widget.entry.note ?? '';
    _factor.text = _factorText(widget.entry);
    for (final controller in [_amount, _factor, _note, _date]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  /// Digits for the amount field. Invalid and absent stay empty, never `0`.
  static String _amountText(MoneyValue? value) {
    final units = value?.asInt;
    if (units == null) return '';
    return '$units';
  }

  /// Ungrouped rate text for multiply/divide. Empty when the line has no rate.
  static String _factorText(LedgerEntryDto entry) {
    final mode = entry.calculationMode;
    final scaled = entry.factorMicros;
    if (scaled == null || !scaled.isValid || scaled.units == null) return '';
    if (mode != CalculationMode.multiply && mode != CalculationMode.divide) {
      return '';
    }
    return const MoneyFormatter().plainScaled(scaled.units!, 6);
  }

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
    final money = ref.watch(apiLayerProvider).money;
    final version = _expectedVersion();
    final normalized = _full ? null : parseUnits(_amount.text)?.toString();
    final typeField = DropdownButton<String>(
      key: const Key('correction-type'),
      value: _type,
      isExpanded: true,
      items: [
        DropdownMenuItem(
          value: 'debt',
          child: Text(movementLabel(section: widget.section, type: 'debt')),
        ),
        DropdownMenuItem(
          value: 'payment',
          child: Text(movementLabel(section: widget.section, type: 'payment')),
        ),
      ],
      onChanged: (value) => setState(() => _type = value ?? 'debt'),
    );
    final paymentField = _type == 'payment' && _allowsFull
        ? DropdownButton<PaymentMode>(
            key: const Key('correction-payment-mode'),
            value: _paymentMode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: PaymentMode.partial,
                child: Text(AppStrings.partialPayment),
              ),
              DropdownMenuItem(
                value: PaymentMode.full,
                child: Text(AppStrings.fullPayment),
              ),
            ],
            onChanged: (value) =>
                setState(() => _paymentMode = value ?? PaymentMode.partial),
          )
        : null;
    final amountField = !_full
        ? UnitsField(
            key: const Key('correction-amount'),
            controller: _amount,
            dense: widget.rowBuilder != null,
            showHint: widget.rowBuilder == null,
            label: AppStrings.amount,
          )
        : null;
    final modeField = !_full
        ? DropdownButton<CalculationMode>(
            key: const Key('correction-mode'),
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
          )
        : null;
    final factorField = !_full && _mode != CalculationMode.direct
        ? TextField(
            key: const Key('correction-factor'),
            controller: _factor,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              isDense: widget.rowBuilder != null,
              labelText: AppStrings.factor,
            ),
          )
        : null;
    final dateField = TextField(
      key: const Key('correction-date'),
      controller: _date,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        isDense: widget.rowBuilder != null,
        labelText: AppStrings.date,
      ),
    );
    final noteField = TextField(
      key: const Key('correction-note'),
      controller: _note,
      decoration: InputDecoration(
        isDense: widget.rowBuilder != null,
        labelText: AppStrings.note,
      ),
    );
    final saveField = GuardedMutation(
      buttonKey: const Key('save-correction'),
      glyph: widget.rowBuilder != null ? Icons.check_rounded : null,
      filled: widget.rowBuilder == null,
      reportErrorInline: widget.rowBuilder == null,
      inputs:
          '${widget.entry.id}|$_type|$_paymentMode|$_mode|$_full|${_amount.text}|${_factor.text}|${_date.text}|${_note.text}',
      expectedVersion: version,
      label: AppStrings.correctTransaction,
      confirmText: AppStrings.confirmCorrect,
      normalizedValue: normalized,
      onSubmit: _submit,
    );
    final builder = widget.rowBuilder;
    if (builder != null) {
      return KeyedSubtree(
        key: const Key('correction-form'),
        child: builder(
          CorrectionRowFields(
            movement: typeField,
            paymentMode: paymentField,
            amount: amountField,
            operation: modeField,
            rate: factorField,
            date: dateField,
            note: noteField,
            save: saveField,
          ),
        ),
      );
    }
    return Column(
      key: const Key('correction-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.correctTransaction,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(AppStrings.noPreview),
        const SizedBox(height: AppSpacing.sm),
        Text(AppStrings.currentServerAmount),
        MoneyText(
          money.formatOrDash(widget.entry.amountUnits, widget.section.currency),
        ),
        LtrText(widget.entry.id),
        if (widget.entry.factorMicros != null)
          widget.entry.factorMicros!.isValid
              ? Text(
                  '${AppStrings.factor} ${money.formatScaled(widget.entry.factorMicros!.units!, 6)}',
                )
              : const MoneyText(MoneyValue.invalidLabel),
        const SizedBox(height: AppSpacing.md),
        typeField,
        if (_type == 'payment' && _allowsFull) paymentField!,
        if (!_full) ...[
          amountField!,
          const SizedBox(height: AppSpacing.md),
          modeField!,
          if (_mode != CalculationMode.direct) factorField!,
        ],
        dateField,
        noteField,
        const SizedBox(height: AppSpacing.md),
        saveField,
      ],
    );
  }

  /// The card's `version` from the latest card fetch. The server checks a
  /// correction against the account version (`customerVersion`), not the
  /// line: production ledger lines have no `version`. A conflict refetch
  /// changes it, and the next send uses that value.
  int? _expectedVersion() => ref
      .watch(accountCardProvider((widget.section, widget.accountId)))
      .asData
      ?.value
      .version;

  Future<String?> _submit(MutationMeta meta) async {
    final parsedDate = DateTime.tryParse(_date.text);
    if (parsedDate == null) return AppStrings.dateInvalid;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final AccountTransactionRequest request;
    if (_full) {
      request = AccountTransactionRequest.fullPayment(
        date: parsedDate,
        note: note,
      );
    } else {
      final units = parseUnits(_amount.text);
      if (units == null) return AppStrings.integerOnly;
      DecimalString? factorValue;
      if (_mode != CalculationMode.direct) {
        factorValue = DecimalString.tryParse(_factor.text);
        if (factorValue == null) return AppStrings.rateInvalid;
      }
      request = _type == 'payment'
          ? AccountTransactionRequest.partialPayment(
              inputValue: units,
              mode: _mode,
              factor: factorValue,
              date: parsedDate,
              note: note,
            )
          : AccountTransactionRequest.debt(
              inputValue: units,
              mode: _mode,
              factor: factorValue,
              date: parsedDate,
              note: note,
            );
    }
    try {
      await ref
          .read(apiLayerProvider)
          .accounts
          .correctTransaction(
            widget.section,
            widget.accountId,
            widget.entry.id,
            request,
            meta,
          );
      if (!mounted) return null;
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      showSavedSnackBar(context);
      // The confirm dialog is the top route while this callback runs. Popping
      // here would dismiss that dialog and leave the form open. Close the form
      // on the next frame, after GuardedMutation has popped the dialog.
      final onDone = widget.onDone;
      if (onDone != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onDone(true));
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route != null && route.isCurrent) {
          navigator.pop(true);
        }
      });
      return null;
    } catch (error) {
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (failure.code == 'VERSION_CONFLICT') {
        ref.invalidate(ledgerProvider((widget.section, widget.accountId)));
        ref.invalidate(accountCardProvider((widget.section, widget.accountId)));
        ref.invalidate(accountsProvider(widget.section));
        return AppStrings.versionConflict;
      }
      return failureText(failure);
    }
  }
}

/// Controls supplied by the correction form; no financial state is duplicated
/// by the table renderer.
class CorrectionRowFields {
  const CorrectionRowFields({
    required this.movement,
    this.paymentMode,
    this.amount,
    this.operation,
    this.rate,
    required this.date,
    required this.note,
    required this.save,
  });
  final Widget movement;
  final Widget? paymentMode;
  final Widget? amount;
  final Widget? operation;
  final Widget? rate;
  final Widget date;
  final Widget note;
  final Widget save;
}
