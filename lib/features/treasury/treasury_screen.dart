import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/labeled_money.dart';
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: ScreenTitle(AppStrings.treasury)),
            IconButton(
              key: const Key('treasury-refresh'),
              tooltip: AppStrings.refresh,
              onPressed: () {
                ref.invalidate(treasuryProvider);
                ref.invalidate(cashLedgerProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (canWrite) ...[
          const SizedBox(height: AppSpacing.sm),
          _WriteActions(
            online: online,
            onEntry: (direction) => _entry(context, ref, direction),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        KeptData<TreasurySummaryDto>(
          value: summary,
          resetKey: 'treasury',
          onRetry: () => ref.invalidate(treasuryProvider),
          messageOf: (error) =>
              failureText(ref.read(errorHandlerProvider).toFailure(error)),
          failureOf: (error) => ref.read(errorHandlerProvider).toFailure(error),
          loading: const SkeletonBox(key: Key('treasury-loading'), height: 180),
          builder: (data) => _Cards(data: data, money: money),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.cashMovements,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        KeptData<Paged<CashEntryDto>>(
          value: ledger,
          resetKey: 'cash',
          onRetry: () => ref.invalidate(cashLedgerProvider),
          messageOf: (error) =>
              failureText(ref.read(errorHandlerProvider).toFailure(error)),
          failureOf: (error) => ref.read(errorHandlerProvider).toFailure(error),
          loading: const SkeletonBox(height: 80),
          builder: (page) =>
              _Movements(page: page, money: money, online: online),
        ),
      ],
    );
  }

  Future<void> _entry(
    BuildContext context,
    WidgetRef ref,
    CashDirection direction,
  ) {
    final version = ref.read(treasuryProvider).asData?.value.version;
    return showAppForm<void>(
      context,
      _CashForm(direction: direction, version: version),
    );
  }
}

class _WriteActions extends StatelessWidget {
  const _WriteActions({required this.online, required this.onEntry});

  final bool online;
  final ValueChanged<CashDirection> onEntry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: GatedButton(
                buttonKey: const Key('cash-in'),
                allowed: true,
                online: online,
                label: AppStrings.cashIn,
                onPressed: () => onEntry(CashDirection.cashIn),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: GatedButton(
                buttonKey: const Key('cash-out'),
                allowed: true,
                online: online,
                destructive: true,
                label: AppStrings.cashOut,
                onPressed: () => onEntry(CashDirection.cashOut),
              ),
            ),
          ],
        );
      },
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
        Text(
          widget.direction == CashDirection.cashIn
              ? AppStrings.cashIn
              : AppStrings.cashOut,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(controller: _amount, label: AppStrings.amount),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: AppStrings.description),
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-cash'),
          inputs: '${widget.direction.name}|${_amount.text}|${_note.text}',
          expectedVersion: widget.version,
          label: AppStrings.save,
          confirmText: AppStrings.confirm,
          normalizedValue: parseUnits(_amount.text)?.toString(),
          onSubmit: _submit,
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta) async {
    final units = parseUnits(_amount.text);
    if (units == null) return AppStrings.integerOnly;
    try {
      final ack = await ref
          .read(apiLayerProvider)
          .treasury
          .addCashEntry(
            CashEntryRequest(
              direction: widget.direction,
              amountUnits: units,
              description: _note.text.trim(),
            ),
            meta,
          );
      _refreshCashViews();
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      if (failure.code == 'VERSION_CONFLICT') _refreshCashViews();
      return failureText(failure);
    }
  }

  void _refreshCashViews() {
    ref.invalidate(treasuryProvider);
    ref.invalidate(cashLedgerProvider);
    ref.invalidate(homeDashboardProvider);
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.data, required this.money});

  final TreasurySummaryDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
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
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
    );
    final rest = [
      _tile(
        context,
        AppStrings.receivables,
        money.formatOrDash(data.receivablesUnits, Currency.lyd),
        AppStrings.ourDebts,
      ),
      _tile(
        context,
        AppStrings.liabilities,
        money.formatOrDash(data.liabilitiesUnits, Currency.lyd),
        AppStrings.owedDebts,
      ),
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
    return LayoutBuilder(
      key: const Key('treasury-summary'),
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = _summaryColumns(width, scale);
        final gap = AppSpacing.md;
        final tileWidth = columns == 1
            ? width
            : ((width - gap * (columns - 1)) / columns).floorToDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            net,
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in rest)
                  SizedBox(width: tileWidth, child: card),
              ],
            ),
          ],
        );
      },
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
    final theme = Theme.of(context);
    final titleStyle =
        (emphasize ? theme.textTheme.titleSmall : theme.textTheme.labelLarge)
            ?.copyWith(color: foreground);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(color: foreground);
    return Card(
      key: title == AppStrings.activeCash
          ? const Key('active-cash-card')
          : null,
      color: background,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: ScaledMoney(
                value,
                style: context.textExtras.amountLarge.copyWith(
                  color: foreground,
                ),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(caption, style: captionStyle),
            ],
          ],
        ),
      ),
    );
  }
}

/// One column when two tiles would be too narrow for the text scale.
int _summaryColumns(double width, double scale) {
  final minTile = 156.0 * (scale < 1.2 ? 1.0 : scale);
  final gap = AppSpacing.md;
  if (width >= minTile * 4 + gap * 3) return 4;
  if (width >= minTile * 3 + gap * 2) return 3;
  if (width >= minTile * 2 + gap) return 2;
  return 1;
}

class _Egyptian extends StatelessWidget {
  const _Egyptian({required this.data, required this.money});

  final TreasurySummaryDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final missing = data.rateMissing || data.egyptianRate == null;
    final scheme = Theme.of(context).colorScheme;
    final source = missing
        ? AppStrings.dash
        : money.formatOrDash(data.egyptianSourceUnits, Currency.egp);
    final converted = missing
        ? AppStrings.dash
        : money.formatOrDash(data.egyptianConvertedUnits, Currency.lyd);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.egyptianTransfers,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (missing) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('rate-missing'),
                width: double.infinity,
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: scheme.error),
                ),
                child: Text(
                  AppStrings.rateMissing,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            LabeledMoney(label: AppStrings.egyptianSource, value: source),
            const SizedBox(height: AppSpacing.xs),
            LabeledMoney(
              label: AppStrings.rate,
              value: money.formatDecimalOrDash(data.egyptianRate),
            ),
            const SizedBox(height: AppSpacing.xs),
            LabeledMoney(label: AppStrings.converted, value: converted),
          ],
        ),
      ),
    );
  }
}

class _Movements extends StatelessWidget {
  const _Movements({
    required this.page,
    required this.money,
    required this.online,
  });

  final Paged<CashEntryDto> page;
  final MoneyFormatter money;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('treasury-movements'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (page.items.isEmpty)
          const EmptyPane(
            key: Key('treasury-empty'),
            message: AppStrings.emptyLedger,
          ),
        for (final entry in page.items) _CashRow(entry: entry, money: money),
        if (page.nextCursor != null)
          _LoadOlderCash(
            cursor: page.nextCursor!,
            seed: page.items,
            online: online,
          ),
      ],
    );
  }
}

class _LoadOlderCash extends ConsumerStatefulWidget {
  const _LoadOlderCash({
    required this.cursor,
    required this.seed,
    required this.online,
  });

  final String cursor;
  final List<CashEntryDto> seed;
  final bool online;

  @override
  ConsumerState<_LoadOlderCash> createState() => _LoadOlderCashState();
}

class _LoadOlderCashState extends ConsumerState<_LoadOlderCash> {
  final _extra = <CashEntryDto>[];
  String? _cursor;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _cursor = widget.cursor;
  }

  @override
  void didUpdateWidget(covariant _LoadOlderCash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cursor != widget.cursor ||
        !_sameSeed(oldWidget.seed, widget.seed)) {
      _extra.clear();
      _cursor = widget.cursor;
      _error = null;
      _busy = false;
    }
  }

  Future<void> _load() async {
    final cursor = _cursor;
    if (cursor == null || _busy || !widget.online) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(apiLayerProvider)
          .treasury
          .cashLedger(before: cursor);
      if (!mounted) return;
      final seen = {
        ...widget.seed.map((entry) => entry.id),
        ..._extra.map((e) => e.id),
      };
      setState(() {
        for (final item in page.items) {
          if (seen.add(item.id)) _extra.add(item);
        }
        _cursor = page.nextCursor;
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

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(apiLayerProvider).money;
    final scheme = Theme.of(context).colorScheme;
    final canTap = widget.online && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _extra) _CashRow(entry: entry, money: money),
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
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const Key('load-older'),
              onPressed: canTap ? _load : null,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _error == null ? AppStrings.loadOlder : AppStrings.retry,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
      ],
    );
  }
}

bool _sameSeed(List<CashEntryDto> a, List<CashEntryDto> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

class _CashRow extends StatelessWidget {
  const _CashRow({required this.entry, required this.money});

  final CashEntryDto entry;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.statusColors;
    final incoming = entry.direction == 'in';
    final outgoing = entry.direction == 'out';
    final label = incoming
        ? AppStrings.cashIn
        : outgoing
        ? AppStrings.cashOut
        : AppStrings.dash;
    final color = incoming
        ? colors.cashPositive
        : outgoing
        ? colors.cashNegative
        : scheme.onSurfaceVariant;
    final theme = Theme.of(context);
    return Card(
      key: Key('cash-entry-${entry.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  incoming ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleSmall),
                      Text(entry.description ?? AppStrings.dash),
                      Text(
                        '${AppStrings.byActor} ${entry.createdByName ?? AppStrings.dash}',
                        style: theme.textTheme.bodySmall,
                      ),
                      LtrText(
                        formatIsoDate(entry.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LabeledMoney(
              label: AppStrings.amount,
              value: money.formatOrDash(entry.amountUnits, Currency.lyd),
              valueStyle: context.textExtras.amount.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            LabeledMoney(
              label: AppStrings.balanceAfter,
              value: money.formatOrDash(entry.balanceAfterUnits, Currency.lyd),
            ),
          ],
        ),
      ),
    );
  }
}
