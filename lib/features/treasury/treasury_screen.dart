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
import '../../ui/widgets/mutation_form.dart';
import '../../ui/widgets/section_kit.dart';

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

    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(width),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: SectionHeading(AppStrings.treasury)),
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
          const SizedBox(height: AppSpacing.md),
          KeptData<TreasurySummaryDto>(
            value: summary,
            resetKey: 'treasury',
            onRetry: () => ref.invalidate(treasuryProvider),
            messageOf: (error) =>
                failureText(ref.read(errorHandlerProvider).toFailure(error)),
            failureOf: (error) =>
                ref.read(errorHandlerProvider).toFailure(error),
            loading: const SkeletonBox(
              key: Key('treasury-loading'),
              height: 180,
            ),
            builder: (data) => _Cards(data: data, money: money),
          ),
          const SizedBox(height: AppSpacing.lg),
          KeptData<Paged<CashEntryDto>>(
            value: ledger,
            resetKey: 'cash',
            onRetry: () => ref.invalidate(cashLedgerProvider),
            messageOf: (error) =>
                failureText(ref.read(errorHandlerProvider).toFailure(error)),
            failureOf: (error) =>
                ref.read(errorHandlerProvider).toFailure(error),
            loading: const SkeletonBox(height: 80),
            builder: (page) => _Movements(
              page: page,
              money: money,
              online: online,
              actions: canWrite
                  ? _WriteActions(
                      online: online,
                      onEntry: (direction) => _entry(context, ref, direction),
                    )
                  : null,
            ),
          ),
        ],
      ),
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

/// Compact دخول (green) / خروج (red) buttons in the ledger's header bar.
class _WriteActions extends StatelessWidget {
  const _WriteActions({required this.online, required this.onEntry});

  final bool online;
  final ValueChanged<CashDirection> onEntry;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    ButtonStyle style(Color fill) => FilledButton.styleFrom(
      backgroundColor: fill,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 34),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      textStyle: cairo(12.5, 800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
    Widget button(
      Key key,
      String label,
      IconData icon,
      Color fill,
      CashDirection direction, {
      bool destructive = false,
    }) => Theme(
      data: Theme.of(
        context,
      ).copyWith(filledButtonTheme: FilledButtonThemeData(style: style(fill))),
      child: GatedButton(
        buttonKey: key,
        allowed: true,
        online: online,
        destructive: destructive,
        label: label,
        leading: icon,
        onPressed: () => onEntry(direction),
      ),
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        button(
          const Key('cash-in'),
          AppStrings.cashIn,
          Icons.download_rounded,
          colors.cashPositive,
          CashDirection.cashIn,
        ),
        button(
          const Key('cash-out'),
          AppStrings.cashOut,
          Icons.upload_rounded,
          colors.cashNegative,
          CashDirection.cashOut,
          destructive: true,
        ),
      ],
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

/// The treasury totals (Ali, 2026-11-04): one framed panel; four equal
/// cards (fixed height, same layout: title, big amount, one-line subtitle),
/// then the gold صافي الخزينة الشامل full width. Figures are the server's.
class _Cards extends StatelessWidget {
  const _Cards({required this.data, required this.money});

  final TreasurySummaryDto data;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final cashColor = switch (data.activeCashTone) {
      SummaryTone.positive => colors.cashPositive,
      SummaryTone.negative => colors.cashNegative,
      _ => null,
    };
    final missing = data.rateMissing || data.egyptianRate == null;
    final source = money.formatOrDash(data.egyptianSourceUnits, Currency.egp);
    final rate = money.formatDecimalOrDash(data.egyptianRate);
    final scheme = Theme.of(context).colorScheme;
    final small = [
      _TotalCard(
        title: AppStrings.receivables,
        value: money.formatOrDash(data.receivablesUnits, Currency.lyd),
        subtitle: Text(AppStrings.ourDebts),
      ),
      _TotalCard(
        title: AppStrings.liabilities,
        value: money.formatOrDash(data.liabilitiesUnits, Currency.lyd),
        subtitle: Text(AppStrings.owedDebts),
      ),
      _TotalCard(
        cardKey: const Key('active-cash-card'),
        title: AppStrings.activeCash,
        value: money.formatOrDash(data.activeCashUnits, Currency.lyd),
        subtitle: const Text(AppStrings.activeCashNote),
        fill: cashColor,
      ),
      _TotalCard(
        title: AppStrings.egyptianTransfers,
        value: missing
            ? null
            : money.formatOrDash(data.egyptianConvertedUnits, Currency.lyd),
        valueKey: const Key('egp-converted'),
        // No rate: the note takes the amount's place, no د.ل figure.
        missing: missing
            ? Container(
                key: const Key('rate-missing'),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
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
              )
            : null,
        // «ج.م X ÷ rate» from the server's source amount and rate.
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(source, key: const Key('egp-source')),
            const Text(' ÷ '),
            LtrText(rate, key: const Key('egp-rate')),
          ],
        ),
      ),
    ];
    final net = _TotalCard(
      title: AppStrings.netTreasury,
      value: money.formatOrDash(data.netUnits, Currency.lyd),
      subtitle: const Text(AppStrings.formulaCaption),
      gold: true,
    );
    return Container(
      key: const Key('treasury-summary'),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: sectionStripGradient,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: sectionGold(context), width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = _summaryColumns(width, scale);
          const gap = AppSpacing.md;
          final tileWidth = columns == 1
              ? width
              : ((width - gap * (columns - 1)) / columns).floorToDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in small)
                    SizedBox(width: tileWidth, child: card),
                ],
              ),
              const SizedBox(height: gap),
              net,
            ],
          );
        },
      ),
    );
  }
}

/// 2 across on phones, 4 across when four fit; 1 at very large text.
int _summaryColumns(double width, double scale) {
  final minTile = 150.0 * (scale < 1.2 ? 1.0 : scale);
  const gap = AppSpacing.md;
  if (width >= minTile * 4 + gap * 3 && width >= 700) return 4;
  if (width >= minTile * 2 + gap) return 2;
  return 1;
}

/// One total card. Fixed height (scaled with the text), centred title,
/// big amount, one-line subtitle; long text shrinks instead of growing.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.cardKey,
    this.valueKey,
    this.fill,
    this.gold = false,
    this.missing,
  });

  final String title;
  final String? value;
  final Widget subtitle;
  final Key? cardKey;
  final Key? valueKey;
  final Color? fill;
  final bool gold;
  final Widget? missing;

  static const gloss = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A2A2E), Color(0xFF0B0B0F)],
  );
  static const goldGloss = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF2B0), Color(0xFFF5C02E), Color(0xFFE0A800)],
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final edge = sectionGold(context);
    final ink = gold
        ? sectionButtonInk
        : fill != null
        ? colors.onStatus
        : Colors.white;
    final soft = gold ? sectionButtonInk : ink.withValues(alpha: 0.82);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final height = (gold ? 128.0 : 120.0) * scale;
    Widget line(Widget child) => SizedBox(
      width: double.infinity,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
    return Card(
      key: cardKey,
      margin: EdgeInsets.zero,
      color: fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: edge.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: fill != null ? null : (gold ? goldGloss : gloss),
          border: Border(top: BorderSide(color: edge, width: 3)),
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: DefaultTextStyle.merge(
          style: cairo(11.5, 600, color: soft),
          maxLines: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              line(Text(title, style: cairo(14, 800, color: ink))),
              if (missing != null)
                line(missing!)
              else
                line(
                  MoneyText(
                    value ?? AppStrings.dash,
                    key: valueKey,
                    style: context.textExtras.amountLarge.copyWith(
                      color: ink,
                      fontSize: gold ? 30 : 24,
                    ),
                  ),
                ),
              line(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

/// سجل الفلوس النشطة, as on the website: a header bar with the title and
/// the دخول / خروج buttons, then a grid with pinned column names, oldest
/// row at the top, opening at the newest (bottom). Rows are tinted by
/// direction. الرصيد is the server's balanceAfterUnits; nothing is computed.
class _Movements extends ConsumerStatefulWidget {
  const _Movements({
    required this.page,
    required this.money,
    required this.online,
    this.actions,
  });

  final Paged<CashEntryDto> page;
  final MoneyFormatter money;
  final bool online;
  final Widget? actions;

  @override
  ConsumerState<_Movements> createState() => _MovementsState();
}

class _CashColumns {
  static const seq = 56.0;
  static const when = 132.0;
  static const move = 72.0;
  static const value = 104.0;
  static const note = 132.0;
  static const by = 96.0;
  static const balance = 112.0;
  static const all = [seq, when, move, value, note, by, balance];
  static double get width => all.fold(0.0, (a, b) => a + b);
}

class _MovementsState extends ConsumerState<_Movements> {
  final _extra = <CashEntryDto>[];
  final _sideways = ScrollController();
  final _rows = ScrollController();
  String? _cursor;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _cursor = widget.page.nextCursor;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNewest());
  }

  @override
  void dispose() {
    _sideways.dispose();
    _rows.dispose();
    super.dispose();
  }

  /// The ledger window opens on the newest row, which sits at the bottom.
  void _showNewest() {
    if (!mounted || !_rows.hasClients) return;
    final position = _rows.position;
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent <= 0) return;
    position.jumpTo(position.maxScrollExtent);
  }

  @override
  void didUpdateWidget(covariant _Movements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.nextCursor != widget.page.nextCursor ||
        !_sameSeed(oldWidget.page.items, widget.page.items)) {
      _extra.clear();
      _cursor = widget.page.nextCursor;
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
        ...widget.page.items.map((entry) => entry.id),
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
    final look = context.look;
    final scheme = Theme.of(context).colorScheme;
    // Server pages are newest first. The grid is oldest at the top and
    // newest at the bottom, and the window opens on that newest row.
    final chronological = [...widget.page.items, ..._extra]
      ..sort((a, b) {
        final byTime = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    final complete = _cursor == null;
    final total = chronological.length;
    final canTap = widget.online && !_busy;
    final screen = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final rowHeight = 52.0 * scale;
    final bodyMax = (screen.height * 0.62).clamp(280.0, 900.0);
    final body = (total * rowHeight + (complete ? 0 : 56)).clamp(
      rowHeight,
      bodyMax,
    );
    final header = Container(
      decoration: BoxDecoration(
        gradient: sectionStripGradient,
        border: Border(bottom: BorderSide(color: sectionGold(context))),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [const PillTitle(AppStrings.cashMovements), ?widget.actions],
      ),
    );
    return Container(
      key: const Key('treasury-movements'),
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: sectionGold(context).withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (chronological.isEmpty)
            const Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.md),
              child: EmptyPane(
                key: Key('treasury-empty'),
                message: AppStrings.emptyLedger,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.maxWidth;
                final stretch = viewport > _CashColumns.width
                    ? viewport / _CashColumns.width
                    : 1.0;
                final widths = [for (final w in _CashColumns.all) w * stretch];
                return Scrollbar(
                  controller: _sideways,
                  child: SingleChildScrollView(
                    key: const Key('treasury-columns-scroll'),
                    controller: _sideways,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _CashColumns.width * stretch,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CashHeader(widths: widths),
                          SizedBox(
                            height: body,
                            child: ListView(
                              key: const Key('treasury-rows'),
                              controller: _rows,
                              padding: EdgeInsets.zero,
                              children: [
                                if (_cursor != null)
                                  SizedBox(
                                    height: 56,
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: SizedBox(
                                        width: viewport,
                                        child: TextButton(
                                          key: const Key('load-older'),
                                          onPressed: canTap ? _load : null,
                                          child: _busy
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text(
                                                  _error == null
                                                      ? AppStrings.loadOlder
                                                      : AppStrings.retry,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                for (var i = 0; i < total; i++)
                                  _CashRow(
                                    entry: chronological[i],
                                    money: widget.money,
                                    widths: widths,
                                    height: rowHeight,
                                    // Row 1 is the oldest once every page is here.
                                    sequence: complete ? '${i + 1}' : null,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
              child: Text(
                _error!,
                key: const Key('load-older-error'),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
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

Color _gridLine(BuildContext context) =>
    sectionGold(context).withValues(alpha: 0.35);

class _CashHeader extends StatelessWidget {
  const _CashHeader({required this.widths});

  final List<double> widths;

  static const labels = [
    AppStrings.ledgerColSeq,
    AppStrings.cashColWhen,
    AppStrings.cashColMove,
    AppStrings.ledgerColValue,
    AppStrings.ledgerColNote,
    AppStrings.ledgerColBy,
    AppStrings.ledgerColBalance,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('treasury-sticky-header'),
      decoration: const BoxDecoration(gradient: sectionStripGradient),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Container(
              width: widths[i],
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: BorderDirectional(
                  end: i == labels.length - 1
                      ? BorderSide.none
                      : BorderSide(color: _gridLine(context)),
                ),
              ),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  labels[i],
                  style: cairo(12, 800, color: sectionStripInk),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  const _CashRow({
    required this.entry,
    required this.money,
    required this.widths,
    required this.height,
    this.sequence,
  });

  final CashEntryDto entry;
  final MoneyFormatter money;
  final List<double> widths;
  final double height;
  final String? sequence;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final colors = context.statusColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final incoming = entry.direction == 'in';
    final outgoing = entry.direction == 'out';
    final label = incoming
        ? AppStrings.cashIn
        : outgoing
        ? AppStrings.cashOut
        : AppStrings.dash;
    final color = incoming
        ? colors.cashPositiveText
        : outgoing
        ? colors.cashNegative
        : look.muted;
    final tint = (incoming ? colors.cashPositive : color).withValues(
      alpha: dark ? 0.24 : 0.13,
    );
    final ink = cairo(12.5, 700, color: look.ink);
    final small = cairo(10.5, 600, color: look.muted);
    final date = entry.createdAt?.toLocal();
    Widget fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);
    final cells = <Widget>[
      fit(Text(sequence ?? AppStrings.dash, style: ink)),
      fit(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (date != null)
              Text(AppStrings.weekdays[date.weekday - 1], style: small),
            fit(LtrText(formatIsoDate(entry.createdAt), style: ink)),
            if (date != null) LtrText(_clock(date), style: small),
          ],
        ),
      ),
      fit(Text(label, style: cairo(12.5, 800, color: color))),
      fit(
        MoneyText(
          money.formatOrDash(entry.amountUnits, Currency.lyd),
          style: context.textExtras.amount.copyWith(color: color, fontSize: 13),
        ),
      ),
      fit(
        Text(
          entry.description ?? AppStrings.dash,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: ink,
        ),
      ),
      fit(
        Text(
          entry.createdByName ?? AppStrings.dash,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: small,
        ),
      ),
      fit(
        MoneyText(
          money.formatOrDash(entry.balanceAfterUnits, Currency.lyd),
          style: context.textExtras.amount.copyWith(
            color: look.ink,
            fontSize: 13,
          ),
        ),
      ),
    ];
    return Container(
      key: Key('cash-entry-${entry.id}'),
      height: height,
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint, look.card),
        border: Border(bottom: BorderSide(color: _gridLine(context))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Container(
              width: widths[i],
              alignment: Alignment.center,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  end: i == cells.length - 1
                      ? BorderSide.none
                      : BorderSide(color: _gridLine(context)),
                ),
              ),
              child: cells[i],
            ),
        ],
      ),
    );
  }
}

String _clock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  final half = value.hour < 12 ? 'ص' : 'م';
  return '$hour:$minute:$second $half';
}
