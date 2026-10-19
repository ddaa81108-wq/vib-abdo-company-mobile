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

class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  static const screenKey = Key('screen-treasury');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.treasury)) return const ForbiddenPane();
    final summary = ref.watch(treasuryProvider);
    final ledger = ref.watch(cashLedgerProvider);
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final canWrite = permissions.canWrite(SectionKey.treasury);
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      key: screenKey,
      padding: pagePadding(width),
      children: [
        const ScreenTitle(AppStrings.treasury),
        const SizedBox(height: AppSpacing.md),
        summary.when(
          loading: () => const SkeletonBox(key: Key('treasury-loading'), height: 180),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(treasuryProvider),
          ),
          data: (data) => _Cards(data: data, money: money, wide: width > AppBreakpoints.phone),
        ),
        if (canWrite)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              GatedButton(
                buttonKey: const Key('cash-in'),
                allowed: true,
                online: online,
                label: AppStrings.cashIn,
                onPressed: () => _entry(context, ref, CashDirection.cashIn),
              ),
              GatedButton(
                buttonKey: const Key('cash-out'),
                allowed: true,
                online: online,
                destructive: true,
                label: AppStrings.cashOut,
                onPressed: () => _entry(context, ref, CashDirection.cashOut),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        ledger.when(
          loading: () => const SkeletonBox(height: 80),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(cashLedgerProvider),
          ),
          data: (page) => Column(
            children: [
              for (final entry in page.items) _CashRow(entry: entry, money: money),
              if (page.nextCursor != null)
                const TextButton(onPressed: null, child: Text(AppStrings.loadOlder)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _entry(BuildContext context, WidgetRef ref, CashDirection direction) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final version = ref.read(treasuryProvider).asData?.value.version;
    await showAppForm<void>(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(direction == CashDirection.cashIn ? AppStrings.cashIn : AppStrings.cashOut),
          UnitsField(controller: amount, label: AppStrings.amount),
          TextField(controller: note, decoration: const InputDecoration(labelText: AppStrings.description)),
          FilledButton(
            onPressed: () async {
              final units = parseUnits(amount.text);
              if (units == null) return;
              try {
                final ack = await ref.read(apiLayerProvider).treasury.addCashEntry(
                  CashEntryRequest(
                    direction: direction,
                    amountUnits: units,
                    description: note.text.trim(),
                  ),
                  MutationMeta(expectedVersion: version),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
                );
                ref.invalidate(treasuryProvider);
                ref.invalidate(cashLedgerProvider);
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
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.data, required this.money, required this.wide});

  final TreasurySummaryDto data;
  final MoneyFormatter money;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final cashColor = data.activeCashUnits == null
        ? null
        : data.activeCashUnits! > 0
        ? colors.cashPositive
        : data.activeCashUnits! < 0
        ? colors.cashNegative
        : null;
    final net = _tile(
      context,
      AppStrings.netTreasury,
      money.formatOrDash(data.netUnits, Currency.lyd),
      AppStrings.formulaCaption,
      emphasize: true,
    );
    final rest = [
      _tile(context, AppStrings.receivables, money.formatOrDash(data.receivablesUnits, Currency.lyd), AppStrings.ourDebts),
      _tile(context, AppStrings.liabilities, money.formatOrDash(data.liabilitiesUnits, Currency.lyd), AppStrings.owedDebts),
      _tile(
        context,
        AppStrings.activeCash,
        money.formatOrDash(data.activeCashUnits, Currency.lyd),
        null,
        background: cashColor,
        foreground: cashColor == null ? null : colors.onStatus,
      ),
      _Egyptian(data: data, money: money),
    ];
    if (!wide) {
      return Column(
        children: [
          net,
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: rest),
        ],
      );
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [net, ...rest],
    );
  }

  Widget _tile(
    BuildContext context,
    String title,
    String value,
    String? caption, {
    bool emphasize = false,
    Color? background,
    Color? foreground,
  }) {
    return SizedBox(
      width: emphasize ? double.infinity : 220,
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: cairo(13, 700, color: foreground)),
              MoneyText(value, style: context.textExtras.amountLarge.copyWith(color: foreground)),
              if (caption != null) Text(caption, style: cairo(11, 500, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Egyptian extends StatelessWidget {
  const _Egyptian({required this.data, required this.money});

  final TreasurySummaryDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final missing = data.rateMissing || data.egyptianRate == null;
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(AppStrings.egyptianTransfers),
              if (missing) const Text(AppStrings.rateMissing),
              Text('${AppStrings.egyptianSource} ${missing ? AppStrings.dash : money.formatOrDash(data.egyptianSourceUnits, Currency.egp)}'),
              Text('${AppStrings.rate} ${money.formatDecimalOrDash(data.egyptianRate)}'),
              Text('${AppStrings.converted} ${missing ? AppStrings.dash : money.formatOrDash(data.egyptianConvertedUnits, Currency.lyd)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  const _CashRow({required this.entry, required this.money});

  final CashEntryDto entry;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final incoming = entry.direction == 'in';
    final color = incoming ? context.statusColors.cashPositive : context.statusColors.cashNegative;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          incoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          textDirection: TextDirection.ltr,
        ),
        title: Text(incoming ? AppStrings.cashIn : AppStrings.cashOut),
        subtitle: Text(
          '${entry.description ?? AppStrings.dash} · ${entry.createdByName ?? AppStrings.dash} · ${formatIsoDate(entry.createdAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MoneyText(money.formatOrDash(entry.amountUnits, Currency.lyd)),
            MoneyText(money.formatOrDash(entry.balanceAfterUnits, Currency.lyd)),
          ],
        ),
      ),
    );
  }
}
