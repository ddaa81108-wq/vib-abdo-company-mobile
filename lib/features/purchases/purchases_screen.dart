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
import '../../ui/widgets/mutation_form.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  static const screenKey = Key('screen-purchases');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.purchases)) {
      return const ForbiddenPane();
    }
    final book = ref.watch(purchaseBookProvider);
    final page = ref.watch(purchasesProvider);
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final canWrite = permissions.canWrite(SectionKey.purchases);
    final canFinalize = permissions.canFinalizePurchases;

    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.purchases),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<PurchaseBook>(
              key: const Key('purchase-books'),
              segments: const [
                ButtonSegment(
                  value: PurchaseBook.alBayan,
                  label: Text(AppStrings.alBayan),
                ),
                ButtonSegment(
                  value: PurchaseBook.simsim,
                  label: Text(AppStrings.simsim),
                ),
              ],
              selected: {book},
              onSelectionChanged: (value) =>
                  ref.read(purchaseBookProvider.notifier).state = value.first,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        KeptData<PurchasesBookPage>(
          value: page,
          resetKey: book,
          onRetry: () => ref.invalidate(purchasesProvider),
          messageOf: (error) =>
              ref.read(errorHandlerProvider).toFailure(error).message,
          loading: const Column(
            key: Key('purchases-loading'),
            children: [
              SkeletonBox(),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(),
            ],
          ),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.page.items.isEmpty)
                const EmptyPane(
                  key: Key('purchases-empty'),
                  message: AppStrings.emptyPurchases,
                ),
              for (final day in data.page.items)
                _DayCard(
                  day: day,
                  money: money,
                  canWrite: canWrite,
                  canFinalize: canFinalize,
                  online: online,
                  book: book,
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.registerTotals,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _LifetimeTotals(totals: data.lifetimeTotals, money: money),
            ],
          ),
        ),
      ],
    );
  }
}

class _LifetimeTotals extends StatelessWidget {
  const _LifetimeTotals({required this.totals, required this.money});

  final PurchasesLifetimeTotalsDto? totals;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('purchases-lifetime'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountLine(
          AppStrings.resultFromServer,
          totals?.resultUnits,
          Currency.lyd,
          money,
        ),
        _AmountLine(AppStrings.paid, totals?.paidUnits, Currency.lyd, money),
        _AmountLine(
          AppStrings.remaining,
          totals?.remainingUnits,
          Currency.lyd,
          money,
        ),
      ],
    );
  }
}

/// Label and server figure. They sit on one line and wrap instead of clipping.
class _AmountLine extends StatelessWidget {
  const _AmountLine(this.label, this.units, this.currency, this.money);

  final String label;
  final int? units;
  final Currency currency;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [Text(label), MoneyText(money.formatOrDash(units, currency))],
      ),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label),
          LtrText(value, style: context.textExtras.tableNumber),
        ],
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.day,
    required this.money,
    required this.canWrite,
    required this.canFinalize,
    required this.online,
    required this.book,
  });

  final PurchaseDayDto day;
  final MoneyFormatter money;
  final bool canWrite;
  final bool canFinalize;
  final bool online;
  final PurchaseBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = dayToneIndex(day.day);
    final band = tone == null ? null : context.statusColors.dayTones[tone];
    final editable = dayIsEditable(day.status);
    final caption = vodafoneCaption(day.vodafoneRemainingUnits);
    return Card(
      key: Key('purchase-day-${day.day}'),
      color: band,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${AppStrings.todayTab} ${day.day}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(dayStatusLabel(day.status)),
              ],
            ),
            _line(AppStrings.previousDebt, day.previousDebtUnits, Currency.lyd),
            _line(AppStrings.todayResult, day.todayResultUnits, Currency.lyd),
            _line(AppStrings.todayPaid, day.todayPaidUnits, Currency.lyd),
            _line(AppStrings.totalDebt, day.totalDebtUnits, Currency.lyd),
            _line(
              AppStrings.vodafoneRemaining,
              day.vodafoneRemainingUnits,
              Currency.egp,
            ),
            if (caption != null) Text(caption),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canWrite && editable)
                  GatedButton(
                    buttonKey: const Key('add-purchase'),
                    allowed: true,
                    online: online,
                    label: AppStrings.add,
                    onPressed: () => showAppForm<void>(
                      context,
                      _PurchaseForm(book: book, version: day.version),
                    ),
                  ),
                if (canFinalize && day.status == 'draft')
                  GuardedMutation(
                    buttonKey: const Key('finalize-day'),
                    inputs: 'finalize:${day.day}:${day.version}',
                    expectedVersion: day.version,
                    label: AppStrings.finalizeDay,
                    confirmText: AppStrings.finalizeConfirm,
                    onSubmit: (meta) => _finalize(context, ref, meta),
                  ),
              ],
            ),
            for (final entry in day.entries)
              _Entry(
                entry: entry,
                money: money,
                book: book,
                version: day.version,
                canWrite: canWrite && editable,
                online: online,
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, int? units, Currency currency) {
    return _AmountLine(label, units, currency, money);
  }

  Future<String?> _finalize(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .purchases
          .finalizeDay(book, meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(purchasesProvider);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _PurchaseForm extends ConsumerStatefulWidget {
  const _PurchaseForm({required this.book, required this.version, this.entry});

  final PurchaseBook book;
  final int? version;
  final PurchaseEntryDto? entry;

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  final _egp = TextEditingController();
  final _rate = TextEditingController();
  final _paid = TextEditingController();
  final _vodafone = TextEditingController();
  final _customLabel = TextEditingController();
  var _mode = CalculationMode.divide;
  String? _itemCode;

  static const _kinds = <(String, String)>[
    (PurchaseItemCodes.vodafoneCash, AppStrings.kindVodafone),
    (PurchaseItemCodes.kafrElSheikh, AppStrings.kindKafr),
    (PurchaseItemCodes.cairo, AppStrings.kindCairo),
    (PurchaseItemCodes.mansoura, AppStrings.kindMansoura),
    (PurchaseItemCodes.fawry, AppStrings.kindFawry),
    (PurchaseItemCodes.banks, AppStrings.kindBanks),
    (PurchaseItemCodes.custom, AppStrings.otherKind),
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _itemCode = entry.itemCode;
      final label = entry.itemLabel;
      if (label != null && label != PurchaseItemCodes.customCaption) {
        _customLabel.text = label;
      }
      if (entry.egpValueUnits != null) _egp.text = '${entry.egpValueUnits}';
      if (entry.paidUnits != null) _paid.text = '${entry.paidUnits}';
      if (entry.vodafoneConsumedUnits != null) {
        _vodafone.text = '${entry.vodafoneConsumedUnits}';
      }
      if (entry.exchangeRate != null) _rate.text = entry.exchangeRate!.value;
      if (entry.calculationMode != null) _mode = entry.calculationMode!;
    }
    for (final controller in [_egp, _rate, _paid, _vodafone, _customLabel]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_egp, _rate, _paid, _vodafone, _customLabel]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custom = _itemCode == PurchaseItemCodes.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(AppStrings.noPreview),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final kind in _kinds)
              ChoiceChip(
                key: Key('purchase-kind-${kind.$1}'),
                label: Text(kind.$2),
                selected: _itemCode == kind.$1,
                onSelected: (_) => setState(() => _itemCode = kind.$1),
              ),
          ],
        ),
        if (custom)
          TextField(
            key: const Key('purchase-custom-label'),
            controller: _customLabel,
            decoration: const InputDecoration(
              labelText: AppStrings.customItemName,
            ),
          ),
        UnitsField(controller: _egp, label: AppStrings.egpValue),
        DropdownButton<CalculationMode>(
          value: _mode,
          isExpanded: true,
          items: const [
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
              setState(() => _mode = value ?? CalculationMode.divide),
        ),
        TextField(
          controller: _rate,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: AppStrings.exchangeRate),
        ),
        UnitsField(controller: _paid, label: AppStrings.paid),
        UnitsField(controller: _vodafone, label: AppStrings.vodafoneConsumed),
        GuardedMutation(
          buttonKey: const Key('save-purchase'),
          inputs:
              '$_itemCode|${_customLabel.text}|$_mode|${_egp.text}|${_rate.text}|${_paid.text}|${_vodafone.text}',
          expectedVersion: widget.version,
          label: AppStrings.save,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final code = _itemCode;
    if (code == null || !PurchaseItemCodes.contains(code)) {
      return AppStrings.chooseKind;
    }
    final customLabel = _customLabel.text.trim();
    if (code == PurchaseItemCodes.custom &&
        (customLabel.isEmpty ||
            customLabel == PurchaseItemCodes.customCaption)) {
      return AppStrings.customItemRequired;
    }
    final value = parseUnits(_egp.text);
    final paidUnits = parseUnits(_paid.text);
    final consumed = _vodafone.text.trim().isEmpty
        ? null
        : parseUnits(_vodafone.text);
    final exchange = DecimalString.tryParse(_rate.text);
    if (value == null || paidUnits == null || exchange == null) {
      return AppStrings.integerOnly;
    }
    if (_vodafone.text.trim().isNotEmpty && consumed == null) {
      return AppStrings.integerOnly;
    }
    final request = PurchaseEntryRequest(
      itemCode: code,
      itemLabel: code == PurchaseItemCodes.custom ? customLabel : null,
      egpValueUnits: value,
      calculationMode: _mode,
      exchangeRate: exchange,
      paidUnits: paidUnits,
      vodafoneConsumedUnits: consumed,
    );
    try {
      final purchases = ref.read(apiLayerProvider).purchases;
      final existing = widget.entry;
      final ack = existing == null
          ? await purchases.create(widget.book, request, meta)
          : await purchases.update(widget.book, existing.id, request, meta);
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(purchasesProvider);
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}

class _Entry extends ConsumerWidget {
  const _Entry({
    required this.entry,
    required this.money,
    required this.book,
    required this.version,
    required this.canWrite,
    required this.online,
  });

  final PurchaseEntryDto entry;
  final MoneyFormatter money;
  final PurchaseBook book;
  final int? version;
  final bool canWrite;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: Key('purchase-entry-${entry.id}'),
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.itemLabel ?? AppStrings.dash,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _AmountLine(
                AppStrings.egpValue,
                entry.egpValueUnits,
                Currency.egp,
                money,
              ),
              _RateLine(
                calculationLabel(entry.calculationMode),
                entry.exchangeRate == null
                    ? AppStrings.dash
                    : money.formatDecimal(entry.exchangeRate!),
              ),
              _AmountLine(
                AppStrings.resultFromServer,
                entry.resultUnits,
                Currency.lyd,
                money,
              ),
              _AmountLine(
                AppStrings.paid,
                entry.paidUnits,
                Currency.lyd,
                money,
              ),
              _AmountLine(
                AppStrings.remaining,
                entry.remainingUnits,
                Currency.lyd,
                money,
              ),
              if (canWrite)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    GatedButton(
                      buttonKey: Key('edit-${entry.id}'),
                      allowed: true,
                      online: online,
                      filled: false,
                      label: AppStrings.edit,
                      onPressed: () => showAppForm<void>(
                        context,
                        _PurchaseForm(
                          book: book,
                          version: version,
                          entry: entry,
                        ),
                      ),
                    ),
                    GuardedMutation(
                      buttonKey: Key('delete-${entry.id}'),
                      inputs: 'delete:${entry.id}:$version',
                      expectedVersion: version,
                      label: AppStrings.delete,
                      filled: false,
                      destructive: true,
                      confirmText: AppStrings.confirmDelete,
                      onSubmit: (meta) => _delete(context, ref, meta),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _delete(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta,
  ) async {
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .purchases
          .delete(book, entry.id, meta);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
        );
      }
      ref.invalidate(purchasesProvider);
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
  }
}
