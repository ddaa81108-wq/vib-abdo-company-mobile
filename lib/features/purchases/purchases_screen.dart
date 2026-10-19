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
    if (!permissions.canRead(SectionKey.purchases)) return const ForbiddenPane();
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
        SegmentedButton<PurchaseBook>(
          segments: const [
            ButtonSegment(value: PurchaseBook.alBayan, label: Text(AppStrings.alBayan)),
            ButtonSegment(value: PurchaseBook.simsim, label: Text(AppStrings.simsim)),
          ],
          selected: {book},
          onSelectionChanged: (value) =>
              ref.read(purchaseBookProvider.notifier).state = value.first,
        ),
        const SizedBox(height: AppSpacing.md),
        page.when(
          loading: () => const SkeletonBox(key: Key('purchases-loading')),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(purchasesProvider),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Text(AppStrings.registerTotals, style: Theme.of(context).textTheme.titleSmall),
              for (final entry in data.lifetimeTotals.entries)
                if (entry.value is int)
                  Text('${entry.key} ${money.formatNumber(entry.value as int)}'),
            ],
          ),
        ),
      ],
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
      color: band,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppStrings.todayTab} ${day.day}', style: Theme.of(context).textTheme.titleSmall),
            Text(dayStatusLabel(day.status)),
            _line(AppStrings.previousDebt, day.previousDebtUnits, Currency.lyd),
            _line(AppStrings.todayResult, day.todayResultUnits, Currency.lyd),
            _line(AppStrings.todayPaid, day.todayPaidUnits, Currency.lyd),
            _line(AppStrings.totalDebt, day.totalDebtUnits, Currency.lyd),
            _line(AppStrings.vodafoneRemaining, day.vodafoneRemainingUnits, Currency.egp),
            if (caption != null) Text(caption),
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
                online: online,
                label: AppStrings.finalizeDay,
                confirmText: AppStrings.finalizeConfirm,
                onSubmit: (meta) => _finalize(context, ref, meta),
              ),
            for (final entry in day.entries) _Entry(entry: entry, money: money),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, int? units, Currency currency) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        MoneyText(money.formatOrDash(units, currency)),
      ],
    );
  }

  Future<String?> _finalize(BuildContext context, WidgetRef ref, MutationMeta meta) async {
    try {
      final ack = await ref.read(apiLayerProvider).purchases.finalizeDay(book, meta);
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
  const _PurchaseForm({required this.book, required this.version});

  final PurchaseBook book;
  final int? version;

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  final _egp = TextEditingController();
  final _rate = TextEditingController();
  final _paid = TextEditingController();
  final _vodafone = TextEditingController();
  var _mode = CalculationMode.divide;
  String? _itemCode;

  static const _kinds = <(String, String)>[
    ('vodafone', AppStrings.kindVodafone),
    ('kafr_el_sheikh', AppStrings.kindKafr),
    ('cairo', AppStrings.kindCairo),
    ('mansoura', AppStrings.kindMansoura),
    ('fawry', AppStrings.kindFawry),
    ('banks', AppStrings.kindBanks),
    ('other', AppStrings.otherKind),
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in [_egp, _rate, _paid, _vodafone]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_egp, _rate, _paid, _vodafone]) {
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
        UnitsField(controller: _egp, label: AppStrings.egpValue),
        DropdownButton<CalculationMode>(
          value: _mode,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: CalculationMode.divide, child: Text(AppStrings.divide)),
            DropdownMenuItem(value: CalculationMode.multiply, child: Text(AppStrings.multiply)),
          ],
          onChanged: (value) => setState(() => _mode = value ?? CalculationMode.divide),
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
          inputs: '$_itemCode|$_mode|${_egp.text}|${_rate.text}|${_paid.text}|${_vodafone.text}',
          expectedVersion: widget.version,
          label: AppStrings.save,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final code = _itemCode;
    if (code == null) return AppStrings.chooseKind;
    final value = parseUnits(_egp.text);
    final paidUnits = parseUnits(_paid.text);
    final consumed = _vodafone.text.trim().isEmpty ? null : parseUnits(_vodafone.text);
    final exchange = DecimalString.tryParse(_rate.text);
    if (value == null || paidUnits == null || exchange == null) return AppStrings.integerOnly;
    if (_vodafone.text.trim().isNotEmpty && consumed == null) return AppStrings.integerOnly;
    try {
      final ack = await ref.read(apiLayerProvider).purchases.create(
        widget.book,
        PurchaseEntryRequest(
          itemCode: code,
          itemLabel: _kinds.firstWhere((kind) => kind.$1 == code).$2,
          egpValueUnits: value,
          calculationMode: _mode,
          exchangeRate: exchange,
          paidUnits: paidUnits,
          vodafoneConsumedUnits: consumed,
        ),
        meta,
      );
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

class _Entry extends StatelessWidget {
  const _Entry({required this.entry, required this.money});

  final PurchaseEntryDto entry;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.itemLabel ?? AppStrings.dash),
          Text('${AppStrings.egpValue} ${money.formatOrDash(entry.egpValueUnits, Currency.egp)}'),
          Text(
            '${calculationLabel(entry.calculationMode)} ${entry.exchangeRate == null ? AppStrings.dash : money.formatDecimal(entry.exchangeRate!)}',
          ),
          Text('${AppStrings.resultFromServer} ${money.formatOrDash(entry.resultUnits, Currency.lyd)}'),
          Text('${AppStrings.paid} ${money.formatOrDash(entry.paidUnits, Currency.lyd)}'),
          Text('${AppStrings.remaining} ${money.formatOrDash(entry.remainingUnits, Currency.lyd)}'),
        ],
      ),
    );
  }
}
