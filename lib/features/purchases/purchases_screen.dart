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
                onPressed: () => _add(context, ref),
              ),
            if (canFinalize && day.status == 'draft')
              GatedButton(
                buttonKey: const Key('finalize-day'),
                allowed: true,
                online: online,
                label: AppStrings.finalizeDay,
                onPressed: () => _finalize(context, ref),
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

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final egp = TextEditingController();
    final rate = TextEditingController();
    final paid = TextEditingController();
    final vodafone = TextEditingController();
    var mode = CalculationMode.divide;
    await showAppForm<void>(
      context,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(AppStrings.noPreview),
            UnitsField(controller: egp, label: AppStrings.egpValue),
            DropdownButton<CalculationMode>(
              value: mode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: CalculationMode.divide, child: Text(AppStrings.divide)),
                DropdownMenuItem(value: CalculationMode.multiply, child: Text(AppStrings.multiply)),
              ],
              onChanged: (value) => setLocal(() => mode = value ?? CalculationMode.divide),
            ),
            TextField(
              controller: rate,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.exchangeRate),
            ),
            UnitsField(controller: paid, label: AppStrings.paid),
            UnitsField(controller: vodafone, label: AppStrings.vodafoneConsumed),
            FilledButton(
              onPressed: () async {
                final value = parseUnits(egp.text);
                final paidUnits = parseUnits(paid.text);
                final consumed = vodafone.text.trim().isEmpty ? null : parseUnits(vodafone.text);
                final exchange = DecimalString.tryParse(rate.text);
                if (value == null || paidUnits == null || exchange == null) return;
                if (vodafone.text.trim().isNotEmpty && consumed == null) return;
                try {
                  final ack = await ref.read(apiLayerProvider).purchases.create(
                    book,
                    PurchaseEntryRequest(
                      itemCode: 'other',
                      itemLabel: AppStrings.otherKind,
                      egpValueUnits: value,
                      calculationMode: mode,
                      exchangeRate: exchange,
                      paidUnits: paidUnits,
                      vodafoneConsumedUnits: consumed,
                    ),
                    MutationMeta(expectedVersion: day.version),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
                  );
                  ref.invalidate(purchasesProvider);
                  Navigator.of(context).pop();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
                  );
                }
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalize(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(AppStrings.finalizeConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.confirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final ack = await ref.read(apiLayerProvider).purchases.finalizeDay(
        book,
        MutationMeta(expectedVersion: day.version),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(purchasesProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(errorHandlerProvider).toFailure(error).message)),
      );
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
