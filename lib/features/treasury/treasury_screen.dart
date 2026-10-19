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
                _LoadOlderCash(cursor: page.nextCursor!, seed: page.items),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _entry(BuildContext context, WidgetRef ref, CashDirection direction) {
    final version = ref.read(treasuryProvider).asData?.value.version;
    return showAppForm<void>(
      context,
      _CashForm(direction: direction, version: version),
    );
  }
}

class _CashForm extends ConsumerStatefulWidget {
  const _CashForm({required this.direction, required this.version});

  final CashDirection direction;
  final int? version;

  @override
  ConsumerState<_CashForm> createState() => _CashFormState();
}

class _CashFormState extends ConsumerState<_CashForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount.addListener(_changed);
    _note.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _amount.removeListener(_changed);
    _note.removeListener(_changed);
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.direction == CashDirection.cashIn ? AppStrings.cashIn : AppStrings.cashOut),
        UnitsField(controller: _amount, label: AppStrings.amount),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: AppStrings.description),
        ),
        GuardedMutation(
          buttonKey: const Key('save-cash'),
          inputs: '${widget.direction.name}|${_amount.text}|${_note.text}',
          expectedVersion: widget.version,
          label: AppStrings.save,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    if (units == null) return AppStrings.integerOnly;
    try {
      final ack = await ref.read(apiLayerProvider).treasury.addCashEntry(
        CashEntryRequest(
          direction: widget.direction,
          amountUnits: units,
          description: _note.text.trim(),
        ),
        meta,
      );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.invalidate(treasuryProvider);
      ref.invalidate(cashLedgerProvider);
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
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
    final cashColor = switch (data.activeCashTone) {
      SummaryTone.positive => colors.cashPositive,
      SummaryTone.negative => colors.cashNegative,
      _ => null,
    };
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

class _LoadOlderCash extends ConsumerStatefulWidget {
  const _LoadOlderCash({required this.cursor, required this.seed});

  final String cursor;
  final List<CashEntryDto> seed;

  @override
  ConsumerState<_LoadOlderCash> createState() => _LoadOlderCashState();
}

class _LoadOlderCashState extends ConsumerState<_LoadOlderCash> {
  final _extra = <CashEntryDto>[];
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
      final page = await ref.read(apiLayerProvider).treasury.cashLedger(before: cursor);
      if (!mounted) return;
      setState(() {
        _extra.addAll(page.items);
        _cursor = page.nextCursor;
        _busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(apiLayerProvider).money;
    return Column(
      children: [
        for (final entry in _extra) _CashRow(entry: entry, money: money),
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
