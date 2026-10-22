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
    super.key,
  });

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;

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
    return GatedButton(
      buttonKey: Key('correct-${entry.id}'),
      allowed: true,
      online: online,
      filled: false,
      label: AppStrings.correctTransaction,
      onPressed: () => _open(context, ref, accountId),
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
    super.key,
  });

  final AccountSection section;
  final String accountId;
  final LedgerEntryDto entry;

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
        DropdownButton<String>(
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
              child: Text(
                movementLabel(section: widget.section, type: 'payment'),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _type = value ?? 'debt'),
        ),
        if (_type == 'payment' && _allowsFull)
          DropdownButton<PaymentMode>(
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
          ),
        if (!_full) ...[
          UnitsField(
            key: const Key('correction-amount'),
            controller: _amount,
            label: AppStrings.amount,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButton<CalculationMode>(
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
              key: const Key('correction-factor'),
              controller: _factor,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.factor),
            ),
        ],
        TextField(
          key: const Key('correction-date'),
          controller: _date,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: AppStrings.date),
        ),
        TextField(
          key: const Key('correction-note'),
          controller: _note,
          decoration: const InputDecoration(labelText: AppStrings.note),
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-correction'),
          inputs:
              '${widget.entry.id}|$_type|$_paymentMode|$_mode|$_full|${_amount.text}|${_factor.text}|${_date.text}|${_note.text}',
          expectedVersion: version,
          label: AppStrings.correctTransaction,
          confirmText: AppStrings.confirmCorrect,
          normalizedValue: normalized,
          onSubmit: _submit,
        ),
      ],
    );
  }

  /// The line's `version` after the latest ledger fetch, else the one this
  /// form opened with. A conflict refetch changes it, and the next send uses
  /// that value.
  int? _expectedVersion() {
    final async = ref.watch(ledgerProvider((widget.section, widget.accountId)));
    if (!async.hasValue) return widget.entry.version;
    final page = async.value;
    if (page == null) return widget.entry.version;
    for (final item in page.page.items) {
      if (item.id == widget.entry.id) return item.version;
    }
    return widget.entry.version;
  }

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
      final ack = await ref
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      // The confirm dialog is the top route while this callback runs. Popping
      // here would dismiss that dialog and leave the form open. Close the form
      // on the next frame, after GuardedMutation has popped the dialog.
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
