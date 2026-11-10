import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../accounts/website_ledger_tone.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';
import '../../ui/widgets/mutation_form.dart';

/// Which ledger row is being written. A null [entryId] is a new row.
class _LedgerDraft {
  const _LedgerDraft({this.entryId});

  final String? entryId;
}

final _ledgerDraftProvider = StateProvider.autoDispose<_LedgerDraft?>((ref) {
  ref.watch(purchaseBookProvider);
  return null;
});

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

    return SectionTheme(
      child: RefreshIndicator(
        key: const Key('purchases-refresh'),
        onRefresh: () async {
          ref.invalidate(purchasesProvider);
          await ref.read(purchasesProvider.future);
        },
        child: KeptData<PurchasesPage>(
          expand: true,
          value: page,
          resetKey: book,
          onRetry: () => ref.invalidate(purchasesProvider),
          messageOf: (error) =>
              failureText(ref.read(errorHandlerProvider).toFailure(error)),
          failureOf: (error) => ref.read(errorHandlerProvider).toFailure(error),
          loading: const Column(
            key: Key('purchases-loading'),
            children: [
              SkeletonBox(),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(),
            ],
          ),
          builder: (data) {
            final day = data.day;
            return _PurchaseHistory(
              key: ValueKey(book),
              book: book,
              first: data.entries,
              firstCursor: data.nextBefore,
              online: online,
              builder: (context, entries, controls) {
                final draft = ref.watch(_ledgerDraftProvider);
                final empty = day == null && entries.isEmpty && draft == null;
                return CustomScrollView(
                  key: PurchasesScreen.screenKey,
                  physics: const AlwaysScrollableScrollPhysics(),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(6000),
                  slivers: [
                    SliverPadding(
                      padding: pagePadding(MediaQuery.sizeOf(context).width),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          if (day != null)
                            SliverToBoxAdapter(
                              child: _DayCard(
                                day: day,
                                money: money,
                                canWrite: canWrite,
                                canFinalize: canFinalize,
                                online: online,
                                book: book,
                              ),
                            ),
                          if (empty)
                            const SliverToBoxAdapter(
                              child: EmptyPane(
                                key: Key('purchases-empty'),
                                message: AppStrings.emptyPurchases,
                              ),
                            ),
                          if (entries.isNotEmpty || draft != null)
                            _PurchaseGrid(
                              entries: entries,
                              money: money,
                              book: book,
                              openDay: day,
                              canWrite: canWrite,
                              canFinalize: canFinalize,
                              online: online,
                            ),
                          SliverToBoxAdapter(
                            child: _OlderPurchasesBar(controls: controls),
                          ),
                          // registerTotals cover the whole merchant register.
                          // Later pages are not added into this figure.
                          SliverToBoxAdapter(
                            child: _RegisterTotals(
                              totals: data.registerTotals,
                              money: money,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The website's words for المشتريات (display only).
abstract final class _PText {
  static const lifetime = 'إجماليات السجل من البداية';
  static const lifeResult = 'إجمالي الناتج';
  static const lifePaid = 'إجمالي المسدد';
  static const lifeRemaining = 'الباقي الحالي';
  static const lifeVodafone = 'إجمالي مستهلك فودافون';
  static const previousValue = 'القيمة السابقة';
  static const workToday = 'إجمالي شغل اليوم';
  static const paidTotal = 'إجمالي المسدد';
  static const vodafoneOurs = 'باقي فودافون لصالحنا';
  static const addDeal = 'إضافة معاملة';
  static const lastRemaining = 'آخر باقي';
  static const colSeq = 'ت';
  static const colKind = 'النوع';
  static const colValue = 'القيمة ج.م';
  static const colSave = '✓';
  static const operation = 'العملية';
  static const rate = 'السعر';
  static const result = 'الناتج';
  static const remaining = 'الباقي';
}

Color _green(BuildContext c) => c.statusColors.creditText;
Color _amber(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFFFBBF24)
    : const Color(0xFFB45309);

/// Light-mode [sectionGold] is orange. The statement frame uses button gold.
Color _frameGold(BuildContext context) =>
    context.look.glass ? sectionGold(context) : sectionButtonGold;

Color _gridLine(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFD6D3D1)
    : const Color(0xFF292524);

const _pillRadius = 22.0;

Widget _gradientPill(
  BuildContext context, {
  required Gradient gradient,
  required Color ink,
  required Widget child,
}) {
  final button = FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    foregroundColor: ink,
    disabledForegroundColor: ink.withValues(alpha: 0.65),
    elevation: 0,
    minimumSize: const Size(double.infinity, 46),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_pillRadius),
    ),
  );
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(_pillRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
    ),
    child: Theme(
      data: Theme.of(context)
          .copyWith(filledButtonTheme: FilledButtonThemeData(style: button)),
      child: child,
    ),
  );
}

Widget _goldAdd(BuildContext context, Widget child) {
  return _gradientPill(
    context,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFE082), Color(0xFFF5C02E), Color(0xFFE0A800)],
    ),
    ink: sectionButtonInk,
    child: child,
  );
}

Widget _greenFinalize(BuildContext context, Widget child) {
  return _gradientPill(
    context,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4ADE80), Color(0xFF16A34A), Color(0xFF166534)],
    ),
    ink: Colors.white,
    child: child,
  );
}

class _OlderControls {
  const _OlderControls({
    required this.cursor,
    required this.busy,
    required this.error,
    required this.load,
  });

  final int? cursor;
  final bool busy;
  final String? error;
  final VoidCallback? load;
}

class _PurchaseHistory extends ConsumerStatefulWidget {
  const _PurchaseHistory({
    required this.book,
    required this.first,
    required this.firstCursor,
    required this.online,
    required this.builder,
    super.key,
  });

  final PurchaseBook book;
  final List<PurchaseEntryDto> first;
  final int? firstCursor;
  final bool online;
  final Widget Function(
    BuildContext context,
    List<PurchaseEntryDto> entries,
    _OlderControls controls,
  )
  builder;

  @override
  ConsumerState<_PurchaseHistory> createState() => _PurchaseHistoryState();
}

class _PurchaseHistoryState extends ConsumerState<_PurchaseHistory> {
  final _extra = <PurchaseEntryDto>[];
  int? _cursor;
  String? _error;
  var _busy = false;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    _cursor = widget.firstCursor;
  }

  @override
  void didUpdateWidget(covariant _PurchaseHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book != widget.book ||
        oldWidget.firstCursor != widget.firstCursor ||
        !_sameIds(oldWidget.first, widget.first)) {
      _ticket++;
      _extra.clear();
      _cursor = widget.firstCursor;
      _error = null;
      _busy = false;
    }
  }

  Future<void> _load() async {
    final cursor = _cursor;
    if (cursor == null || _busy || !widget.online) return;
    final ticket = ++_ticket;
    final book = widget.book;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(apiLayerProvider)
          .purchases
          .list(book, before: cursor);
      if (!mounted || ticket != _ticket || book != widget.book) return;
      final seen = {
        ...widget.first.map((entry) => entry.id),
        ..._extra.map((entry) => entry.id),
      };
      setState(() {
        for (final entry in page.entries) {
          if (seen.add(entry.id)) _extra.add(entry);
        }
        _cursor = page.nextBefore;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || ticket != _ticket || book != widget.book) return;
      setState(() {
        _busy = false;
        _error = failureText(ref.read(errorHandlerProvider).toFailure(error));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...widget.first, ..._extra];
    return widget.builder(
      context,
      entries,
      _OlderControls(
        cursor: _cursor,
        busy: _busy,
        error: _error,
        load: _cursor != null && widget.online && !_busy ? _load : null,
      ),
    );
  }
}

bool _sameIds(List<PurchaseEntryDto> a, List<PurchaseEntryDto> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

class _OlderPurchasesBar extends StatelessWidget {
  const _OlderPurchasesBar({required this.controls});

  final _OlderControls controls;

  @override
  Widget build(BuildContext context) {
    if (controls.cursor == null && controls.error == null && !controls.busy) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controls.error != null)
            Text(
              controls.error!,
              key: const Key('purchases-older-error'),
              style: cairo(13, 700, color: scheme.error),
            ),
          if (controls.cursor != null)
            OutlinedButton(
              key: const Key('purchases-older'),
              onPressed: controls.load,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(
                controls.busy
                    ? AppStrings.ledgerLoadingOlder
                    : AppStrings.loadOlder,
              ),
            ),
        ],
      ),
    );
  }
}

class _RegisterTotals extends StatelessWidget {
  const _RegisterTotals({required this.totals, required this.money});

  final PurchasesRegisterTotalsDto? totals;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    String f(MoneyValue? v, Currency c) => money.formatOrDash(v, c);
    final remaining = totals?.remainingUnits?.asInt;
    final remainingGloss = remaining == null || remaining == 0
        ? websiteLedgerSlate
        : remaining > 0
        ? websiteLedgerRed
        : websiteLedgerGreen;
    return DecoratedBox(
      key: const Key('purchases-lifetime'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7AE12), width: 1.4),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF141414)
            : const Color(0xFFFFFBF0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _PText.lifetime,
              textAlign: TextAlign.center,
              style: cairo(14, 800, color: const Color(0xFFE7AE12)),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: remainingGloss.decoration(BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      _PText.lifeRemaining,
                      style: cairo(12, 700, color: remainingGloss.ink),
                    ),
                    Text(
                      f(totals?.remainingUnits, Currency.lyd),
                      style: cairo(20, 800, color: remainingGloss.amount),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            PairGrid(
              children: [
                EdgeSummary(
                  title: _PText.lifeResult,
                  value: f(totals?.resultUnits, Currency.lyd),
                  edge: sectionGold(context),
                ),
                EdgeSummary(
                  title: _PText.lifePaid,
                  value: f(totals?.paidUnits, Currency.lyd),
                  edge: _green(context),
                ),
                EdgeSummary(
                  title: _PText.lifeVodafone,
                  value: f(totals?.vodafoneConsumedUnits, vodafoneCurrency),
                  edge: _amber(context),
                ),
                EdgeSummary(
                  title: AppStrings.vodafoneRemaining,
                  value: f(totals?.vodafoneRemainingUnits, vodafoneCurrency),
                  edge: _green(context),
                ),
              ],
            ),
          ],
        ),
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
    final label = day.numberLabel;
    final correctionOpen = day.correctionOpen;
    final editable = day.status == 'draft' || correctionOpen;
    final caption = vodafoneCaption(day.vodafoneRemainingUnits);
    final owed = caption == AppStrings.vodafoneOwed;
    String f(MoneyValue? v, Currency c) => money.formatOrDash(v, c);
    final showAdd = canWrite && editable && day.version != null;
    final showFinalize =
        canFinalize && day.status == 'draft' && day.version != null;
    final width = MediaQuery.sizeOf(context).width;
    final cardH = (55 * width / 318).clamp(52.0, 76.0);
    final gap = (5 * width / 318).clamp(4.0, 7.0);
    final radius = (9 * width / 318).clamp(8.0, 12.0);
    const white = Color(0xFFFFFFFF);
    const paleGold = Color(0xFFF6E7A8);
    const coral = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFF6B6B), Color(0xFFE11D48), Color(0xFFBE123C)],
    );
    const glossBlack = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3F3F46), Color(0xFF18181B), Color(0xFF09090B)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _frameGold(context), width: 1.4),
          ),
          child: Padding(
            key: Key('purchase-day-$label'),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bookPills(context, ref),
                if (showAdd || showFinalize) ...[
                  SizedBox(height: gap),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: showAdd
                            ? _goldAdd(
                                context,
                                GatedButton(
                                  buttonKey: ValueKey('add-purchase-$label'),
                                  allowed: true,
                                  online: online,
                                  leading: Icons.add,
                                  label: _PText.addDeal,
                                  onPressed: () =>
                                      ref
                                              .read(
                                                _ledgerDraftProvider.notifier,
                                              )
                                              .state =
                                          const _LedgerDraft(),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: showFinalize
                            ? _greenFinalize(
                                context,
                                GuardedMutation(
                                  buttonKey: ValueKey('finalize-day-$label'),
                                  inputs: 'finalize:$label:${day.version}',
                                  expectedVersion: day.version,
                                  leading: Icons.check_circle_outline,
                                  label: AppStrings.finalizeDay,
                                  confirmText: AppStrings.finalizeConfirm,
                                  onSubmit: (meta) =>
                                      _finalize(context, ref, meta),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CorrectionStatus(
              day: label,
              status: day.status,
              open: correctionOpen,
            ),
            if (canFinalize && day.status == 'finalized' && !correctionOpen)
              GuardedMutation(
                buttonKey: Key('open-correction-$label'),
                inputs: 'open-correction:$label:${day.version}',
                expectedVersion: day.version,
                label: AppStrings.openDayCorrection,
                confirmText: AppStrings.openCorrectionConfirm,
                onVersionConflict: () => ref.invalidate(purchasesProvider),
                onSubmit: (meta) => _correct(context, ref, meta, open: true),
              ),
            if (canFinalize && correctionOpen)
              GuardedMutation(
                buttonKey: Key('close-correction-$label'),
                inputs: 'close-correction:$label:${day.version}',
                expectedVersion: day.version,
                label: AppStrings.closeDayCorrection,
                confirmText: AppStrings.closeCorrectionConfirm,
                onVersionConflict: () => ref.invalidate(purchasesProvider),
                onSubmit: (meta) => _correct(context, ref, meta, open: false),
              ),
          ],
        ),
        SizedBox(height: gap),
        _totalPair(
          gap: gap,
          height: cardH,
          right: _TotalTile(
            tileKey: const Key('purchase-total-previous'),
            label: _PText.previousValue,
            value: f(day.previousDebtUnits, Currency.lyd),
            gradient: coral,
            ink: white,
            border: Colors.white.withValues(alpha: 0.45),
            radius: radius,
          ),
          left: _TotalTile(
            tileKey: const Key('purchase-total-work'),
            label: _PText.workToday,
            value: f(day.todayResultUnits, Currency.lyd),
            gradient: glossBlack,
            ink: paleGold,
            border: const Color(0xFFF5C02E),
            radius: radius,
          ),
        ),
        SizedBox(height: gap),
        _totalPair(
          gap: gap,
          height: cardH,
          right: _TotalTile(
            tileKey: const Key('purchase-total-paid'),
            label: _PText.paidTotal,
            value: f(day.todayPaidUnits, Currency.lyd),
            gradient: glossBlack,
            ink: paleGold,
            border: const Color(0xFFF5C02E),
            radius: radius,
          ),
          left: _TotalTile(
            tileKey: const Key('purchase-total-debt'),
            label: AppStrings.totalDebt,
            value: f(day.totalDebtUnits, Currency.lyd),
            gradient: coral,
            ink: white,
            border: Colors.white.withValues(alpha: 0.45),
            radius: radius,
          ),
        ),
        SizedBox(height: gap),
        _TotalTile(
          tileKey: const Key('purchase-vodafone-ours'),
          label: _PText.vodafoneOurs,
          value: f(day.vodafoneRemainingUnits, vodafoneCurrency),
          fill: const Color(0xFFF3F7E8),
          ink: const Color(0xFF166534),
          border: const Color(0xFF86EFAC),
          radius: radius,
          note: owed ? caption : null,
          height: cardH + 8,
        ),
      ],
    );
  }

  Widget _bookPills(BuildContext context, WidgetRef ref) {
    final gold = _frameGold(context);
    final book = ref.watch(purchaseBookProvider);
    return SegmentedButton<PurchaseBook>(
      key: const Key('purchase-books'),
      expandedInsets: EdgeInsets.zero,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1A1A1A);
          }
          return const Color(0xFF2A2F38);
        }),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFFF5F5F4)),
        side: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return BorderSide(
            color: selected ? gold : const Color(0xFFD6D3D1),
            width: selected ? 1.6 : 1,
          );
        }),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
      ),
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
    );
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
      return failureText(ref.read(errorHandlerProvider).toFailure(error));
    }
  }

  Future<String?> _correct(
    BuildContext context,
    WidgetRef ref,
    MutationMeta meta, {
    required bool open,
  }) async {
    final ack = await ref
        .read(apiLayerProvider)
        .purchases
        .setDayCorrection(book, day.id, open: open, meta: meta);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
    }
    ref.invalidate(purchasesProvider);
    return null;
  }
}

class _InlineLedgerRow extends ConsumerStatefulWidget {
  const _InlineLedgerRow({
    required this.book,
    required this.version,
    required this.money,
    required this.scale,
    required this.actionWidth,
    this.entry,
    super.key,
  });

  final PurchaseBook book;

  /// Open day version sent as `expectedDayVersion`.
  final int? version;
  final MoneyFormatter money;
  final double scale;
  final double actionWidth;
  final PurchaseEntryDto? entry;

  @override
  ConsumerState<_InlineLedgerRow> createState() => _InlineLedgerRowState();
}

class _InlineLedgerRowState extends ConsumerState<_InlineLedgerRow> {
  final _egp = TextEditingController();
  final _rate = TextEditingController();
  final _paid = TextEditingController();
  final _vodafone = TextEditingController();
  final _customLabel = TextEditingController();
  final _valueFocus = FocusNode();
  final _opFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _paidFocus = FocusNode();
  final _vodafoneFocus = FocusNode();
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
    for (final node in [
      _valueFocus,
      _opFocus,
      _rateFocus,
      _paidFocus,
      _vodafoneFocus,
    ]) {
      node.addListener(() => _onFocus(node));
    }
    final entry = widget.entry;
    if (entry != null) {
      _itemCode = entry.itemCode;
      final label = entry.itemLabel;
      if (label != null && label != PurchaseItemCodes.customCaption) {
        _customLabel.text = label;
      }
      _prefill(_egp, entry.egpValueUnits);
      _prefill(_paid, entry.paidUnits);
      _prefill(_vodafone, entry.vodafoneConsumedUnits);
      if (entry.exchangeRate != null) _rate.text = entry.exchangeRate!.value;
      if (entry.calculationMode != null) _mode = entry.calculationMode!;
    }
    for (final controller in [_egp, _rate, _paid, _vodafone, _customLabel]) {
      controller.addListener(_changed);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _valueFocus.requestFocus();
    });
  }

  void _changed() => setState(() {});

  void _onFocus(FocusNode node) {
    if (!mounted) return;
    setState(() {});
    if (!node.hasFocus) return;
    final target = node.context;
    if (target == null) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
  }

  void _next(FocusNode node) => node.requestFocus();

  void _prefill(TextEditingController controller, MoneyValue? value) {
    if (value != null && value.isValid && value.units != null) {
      controller.text = '${value.units}';
    }
  }

  @override
  void dispose() {
    for (final controller in [_egp, _rate, _paid, _vodafone, _customLabel]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    for (final node in [
      _valueFocus,
      _opFocus,
      _rateFocus,
      _paidFocus,
      _vodafoneFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custom = _itemCode == PurchaseItemCodes.custom;
    final line = _gridLine(context);
    final width = _ledgerCols.map((col) => col.$2 * widget.scale).toList();
    final existing = widget.entry;
    final result = existing == null
        ? AppStrings.dash
        : widget.money.formatOrDash(existing.resultUnits, Currency.lyd);
    final remaining = existing == null
        ? AppStrings.dash
        : widget.money.formatOrDash(existing.remainingUnits, Currency.lyd);
    Widget cell({
      required int index,
      required Widget child,
      bool focused = false,
    }) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: sectionButtonGold.withValues(alpha: 0.14),
          border: Border.all(
            color: focused ? sectionButtonGold : line,
            width: focused ? 2 : 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: width[index],
            maxWidth: width[index],
            minHeight: 72,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: child,
          ),
        ),
      );
    }

    final fieldPad = const EdgeInsets.fromLTRB(72, 96, 72, 180);
    final quietFields = Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
    return Theme(
      data: quietFields,
      child: Row(
        key: const Key('purchase-inline-row'),
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(
            index: 0,
            child: Center(
              child: Text(
                existing?.sequence?.toString() ?? '—',
                style: cairo(14, 800, color: context.look.ink),
              ),
            ),
          ),
          cell(
            index: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final kind in _kinds)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: ChoiceChip(
                              key: Key('purchase-kind-${kind.$1}'),
                              label: Text(kind.$2),
                              selected: _itemCode == kind.$1,
                              onSelected: (_) =>
                                  setState(() => _itemCode = kind.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (custom)
                  TextField(
                    key: const Key('purchase-custom-label'),
                    controller: _customLabel,
                    decoration: const InputDecoration(
                      labelText: AppStrings.customItemName,
                      isDense: true,
                    ),
                  ),
              ],
            ),
          ),
          cell(
            index: 2,
            focused: _valueFocus.hasFocus,
            child: UnitsField(
              key: const Key('purchase-field-value'),
              controller: _egp,
              focusNode: _valueFocus,
              label: '',
              showHint: false,
              dense: true,
              scrollPadding: fieldPad,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _next(_rateFocus),
              onSubmitted: (_) => _next(_rateFocus),
            ),
          ),
          cell(
            index: 3,
            focused: _opFocus.hasFocus,
            child: DropdownButton<CalculationMode>(
              focusNode: _opFocus,
              value: _mode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: CalculationMode.divide,
                  child: CalculationMark(CalculationMode.divide),
                ),
                DropdownMenuItem(
                  value: CalculationMode.multiply,
                  child: CalculationMark(CalculationMode.multiply),
                ),
              ],
              onChanged: (value) {
                setState(() => _mode = value ?? CalculationMode.divide);
                _next(_rateFocus);
              },
            ),
          ),
          cell(
            index: 4,
            focused: _rateFocus.hasFocus,
            child: TextField(
              key: const Key('purchase-field-rate'),
              controller: _rate,
              focusNode: _rateFocus,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              scrollPadding: fieldPad,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
              onEditingComplete: () => _next(_paidFocus),
              onSubmitted: (_) => _next(_paidFocus),
            ),
          ),
          cell(
            index: 5,
            child: Center(
              child: Text(
                result,
                textAlign: TextAlign.center,
                style: cairo(12, 700, color: context.look.muted),
              ),
            ),
          ),
          cell(
            index: 6,
            focused: _paidFocus.hasFocus,
            child: UnitsField(
              key: const Key('purchase-field-paid'),
              controller: _paid,
              focusNode: _paidFocus,
              label: '',
              showHint: false,
              dense: true,
              scrollPadding: fieldPad,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _next(_vodafoneFocus),
              onSubmitted: (_) => _next(_vodafoneFocus),
            ),
          ),
          cell(
            index: 7,
            child: Center(
              child: Text(
                remaining,
                textAlign: TextAlign.center,
                style: cairo(12, 700, color: context.look.muted),
              ),
            ),
          ),
          cell(
            index: 8,
            focused: _vodafoneFocus.hasFocus,
            child: UnitsField(
              key: const Key('purchase-field-vodafone'),
              controller: _vodafone,
              focusNode: _vodafoneFocus,
              label: '',
              showHint: false,
              dense: true,
              scrollPadding: fieldPad,
              textInputAction: TextInputAction.done,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: sectionButtonGold.withValues(alpha: 0.14),
              border: Border.all(color: line),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.actionWidth,
                maxWidth: widget.actionWidth,
                minHeight: 72,
              ),
              child: GuardedMutation(
                buttonKey: const Key('save-purchase'),
                inputs:
                    '$_itemCode|${_customLabel.text}|$_mode|${_egp.text}|${_rate.text}|${_paid.text}|${_vodafone.text}',
                expectedVersion: widget.version,
                glyph: Icons.check,
                label: AppStrings.save,
                onSubmit: _submit,
              ),
            ),
          ),
        ],
      ),
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
          : await purchases.update(
              widget.book,
              existing.id,
              request,
              meta,
              entryVersion: existing.version,
            );
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
      ref.read(_ledgerDraftProvider.notifier).state = null;
      ref.invalidate(purchasesProvider);
      return null;
    } catch (error) {
      return failureText(ref.read(errorHandlerProvider).toFailure(error));
    }
  }
}

class _CorrectionStatus extends StatelessWidget {
  const _CorrectionStatus({
    required this.day,
    required this.status,
    required this.open,
  });

  final String day;
  final String? status;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final carried = status == 'finalized' && !open;
    final editing = open;
    final background = editing ? colors.chipReviewBg : colors.chipNormalBg;
    final foreground = editing ? colors.chipReviewFg : colors.chipNormalFg;
    // «التصحيح مغلق» was the app's name for a finalized day whose
    // correction session is shut. The website says «مُرحّل» for that,
    // «اليوم الحالي» while the day is still a draft, and «مفتوح للتعديل»
    // after «تعديل اليوم».
    final label = editing
        ? AppStrings.purchaseEditing
        : carried
        ? AppStrings.purchaseCarried
        : AppStrings.purchaseToday;
    return Container(
      key: Key('correction-status-$day'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(label, style: cairo(11, 800, color: foreground)),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.tileKey,
    required this.label,
    required this.value,
    required this.ink,
    required this.border,
    required this.radius,
    this.gradient,
    this.fill,
    this.note,
    this.height,
  });

  final Key tileKey;
  final String label;
  final String value;
  final Color ink;
  final Color border;
  final double radius;
  final Gradient? gradient;
  final Color? fill;
  final String? note;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? fill : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1.2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: cairo(12, 800, color: ink),
            ),
            if (note != null)
              Text(
                note!,
                textAlign: TextAlign.center,
                style: cairo(11, 600, color: ink),
              ),
            const SizedBox(height: 2),
            MoneyText(
              value,
              align: TextAlign.center,
              style: context.textExtras.amount.copyWith(
                color: ink,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _totalPair({
  required double gap,
  required double height,
  required Widget right,
  required Widget left,
}) {
  return SizedBox(
    height: height,
    child: Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(child: right),
        SizedBox(width: gap),
        Expanded(child: left),
      ],
    ),
  );
}

const _ledgerCols = <(String, double)>[
  (_PText.colSeq, 48),
  (_PText.colKind, 188),
  (_PText.colValue, 132),
  (_PText.operation, 56),
  (_PText.rate, 88),
  (_PText.result, 72),
  (AppStrings.paid, 72),
  (_PText.remaining, 72),
  (AppStrings.vodafoneConsumed, 108),
];

const _ledgerActionWidth = 96.0;
const _ledgerHeaderH = 56.0;
const _ledgerRowH = 64.0;
const _ledgerBreakH = 48.0;

/// Oldest day first, then that day's server [PurchaseEntryDto.sequence].
List<PurchaseEntryDto> _oldestFirst(List<PurchaseEntryDto> entries) {
  final copy = [...entries];
  copy.sort((a, b) {
    final byDate = (a.businessDate ?? '').compareTo(b.businessDate ?? '');
    if (byDate != 0) return byDate;
    final byDay = (a.dayNumber ?? 1 << 20).compareTo(b.dayNumber ?? 1 << 20);
    if (byDay != 0) return byDay;
    final bySeq = (a.sequence ?? 1 << 20).compareTo(b.sequence ?? 1 << 20);
    if (bySeq != 0) return bySeq;
    return (a.createdAt ?? a.id).compareTo(b.createdAt ?? b.id);
  });
  return copy;
}

sealed class _LedgerLine {
  const _LedgerLine();
}

class _LedgerEntryLine extends _LedgerLine {
  const _LedgerEntryLine(this.entry);
  final PurchaseEntryDto entry;
}

class _LedgerBreakLine extends _LedgerLine {
  const _LedgerBreakLine({
    required this.dayId,
    required this.closing,
    required this.nextDate,
    required this.dayNumber,
    required this.closedDate,
    required this.dayStatus,
    required this.correctionOpen,
    required this.dayVersion,
  });
  final String dayId;
  final MoneyValue? closing;

  /// `businessDate` of the first row of the following day. Not today's clock.
  final String? nextDate;
  final int? dayNumber;
  final String? closedDate;
  final String? dayStatus;
  final bool correctionOpen;
  final int? dayVersion;
}

/// A visual break before the next day, using that closed day's
/// `dayClosingDebtUnits`. Not a computed balance and not a new row.
List<_LedgerLine> _ledgerLines(List<PurchaseEntryDto> entries) {
  final sorted = _oldestFirst(entries);
  final lines = <_LedgerLine>[];
  for (var i = 0; i < sorted.length; i++) {
    final entry = sorted[i];
    if (i > 0 && entry.dayId != sorted[i - 1].dayId) {
      final closed = sorted[i - 1];
      lines.add(
        _LedgerBreakLine(
          dayId: closed.dayId ?? 'unknown-$i',
          closing: closed.dayClosingDebtUnits,
          nextDate: entry.businessDate,
          dayNumber: closed.dayNumber,
          closedDate: closed.businessDate,
          dayStatus: closed.dayStatus,
          correctionOpen: closed.correctionOpen,
          dayVersion: closed.dayVersion,
        ),
      );
    }
    lines.add(_LedgerEntryLine(entry));
  }
  return lines;
}

class _PurchaseGrid extends ConsumerWidget {
  const _PurchaseGrid({
    required this.entries,
    required this.money,
    required this.book,
    required this.openDay,
    required this.canWrite,
    required this.canFinalize,
    required this.online,
  });

  final List<PurchaseEntryDto> entries;
  final MoneyFormatter money;
  final PurchaseBook book;
  final PurchaseDayDto? openDay;
  final bool canWrite;
  final bool canFinalize;
  final bool online;

  /// A draft row on the open day can be edited. A carried day
  /// («مُرحّل») can be edited only after «تعديل اليوم» sets
  /// `correctionOpen` on that day, which is the website's rule.
  bool _writable(PurchaseEntryDto entry) {
    if (!canWrite || entry.dayVersion == null) return false;
    if (entry.dayStatus == 'draft') {
      return entry.dayId != null && entry.dayId == openDay?.id;
    }
    return entry.dayStatus == 'finalized' && entry.correctionOpen;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
    final draft = ref.watch(_ledgerDraftProvider);
    final lines = _ledgerLines(entries);
    final gold = _frameGold(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final headerH = _ledgerHeaderH * scale;
    final rowH = _ledgerRowH * scale;
    final breakH = _ledgerBreakH * scale;
    final actionW = _ledgerActionWidth * scale;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final headerFill = const Color(0xFF111111);
    final breakFill = dark ? const Color(0xFF3F3F46) : const Color(0xFFE7E5E4);
    final breakInk = dark ? const Color(0xFFE7E5E4) : const Color(0xFF44403C);
    final figure = context.textExtras.amount.copyWith(
      fontSize: 13,
      color: look.ink,
    );
    Widget moneyCell(MoneyValue? value, Currency currency, {Color? color}) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: MoneyText(
          money.formatOrDash(value, currency),
          style: color == null ? figure : figure.copyWith(color: color),
        ),
      );
    }

    List<Widget> dataCells(_LedgerEntryLine line, Color ink) {
      final entry = line.entry;
      final seq = entry.sequence?.toString() ?? AppStrings.dash;
      final kind = (entry.itemLabel ?? '').trim().isEmpty
          ? AppStrings.dash
          : entry.itemLabel!.trim();
      final rate = entry.exchangeRate == null
          ? AppStrings.dash
          : money.formatDecimal(entry.exchangeRate!);
      final op =
          entry.calculationMode == CalculationMode.divide ||
              entry.calculationMode == CalculationMode.multiply
          ? CalculationMark(entry.calculationMode, style: figure)
          : Text(AppStrings.dash, style: figure);
      return [
        Text(seq, style: cairo(14, 800, color: ink)),
        Text(
          kind,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: cairo(13, 700, color: ink),
        ),
        moneyCell(entry.egpValueUnits, Currency.egp, color: ink),
        op,
        LtrText(rate, style: figure.copyWith(color: ink)),
        moneyCell(entry.resultUnits, Currency.lyd, color: ink),
        moneyCell(entry.paidUnits, Currency.lyd, color: ink),
        moneyCell(entry.remainingUnits, Currency.lyd, color: ink),
        moneyCell(entry.vodafoneConsumedUnits, vodafoneCurrency, color: ink),
      ];
    }

    Widget band({
      required double height,
      required Color color,
      required List<Widget> cells,
      required Color lineColor,
      Widget? tail,
      Key? cellKey,
    }) {
      return ColoredBox(
        color: color,
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _ledgerCols.length; i++)
              DecoratedBox(
                key: i == 0 && cellKey != null ? cellKey : null,
                decoration: BoxDecoration(
                  border: Border.all(color: lineColor, width: 1),
                ),
                child: SizedBox(
                  width: _ledgerCols[i].$2 * scale,
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(fit: BoxFit.scaleDown, child: cells[i]),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: lineColor, width: 1),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: actionW,
                  maxWidth: actionW,
                  minHeight: height,
                ),
                child: tail ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
    }

    final scrollBands = <Widget>[
      band(
        height: headerH,
        color: headerFill,
        lineColor: sectionButtonGold,
        cells: [
          for (final col in _ledgerCols)
            Text(
              col.$1,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: cairo(12, 800, color: sectionStripInk),
            ),
        ],
        tail: Center(
          child: Text(
            _PText.colSave,
            style: cairo(16, 800, color: sectionButtonGold),
          ),
        ),
      ),
    ];

    for (final line in lines) {
      switch (line) {
        case _LedgerBreakLine(
          :final dayId,
          :final closing,
          :final nextDate,
          :final dayNumber,
          :final closedDate,
          :final dayStatus,
          :final correctionOpen,
          :final dayVersion,
        ):
          final tableWidth =
              _ledgerCols.fold<double>(0, (sum, col) => sum + col.$2 * scale) +
              actionW;
          scrollBands.add(
            ConstrainedBox(
              key: Key('purchase-rollover-$dayId'),
              constraints: BoxConstraints(
                minHeight: breakH + 8,
                minWidth: tableWidth,
                maxWidth: tableWidth,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: breakFill,
                  border: Border.symmetric(
                    horizontal: BorderSide(color: _gridLine(context), width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'يوم #${dayNumber ?? '—'}',
                              style: cairo(13, 800, color: breakInk),
                            ),
                            Text(
                              closedDate ?? AppStrings.dash,
                              style: cairo(12, 700, color: breakInk),
                            ),
                            Text(
                              nextDate ?? AppStrings.dash,
                              style: cairo(12, 700, color: breakInk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sectionButtonGold),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _PText.lastRemaining,
                                style: cairo(11, 700, color: sectionButtonGold),
                              ),
                              MoneyText(
                                money.formatOrDash(closing, Currency.lyd),
                                style: figure.copyWith(
                                  color: const Color(0xFFFFF8CC),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (canFinalize &&
                          dayStatus == 'finalized' &&
                          dayVersion != null) ...[
                        const SizedBox(width: 8),
                        GuardedMutation(
                          buttonKey: Key('day-correction-$dayId'),
                          inputs:
                              'day-correction:$dayId:$correctionOpen:$dayVersion',
                          expectedVersion: dayVersion,
                          label: correctionOpen
                              ? AppStrings.closeDayCorrection
                              : AppStrings.openDayCorrection,
                          onVersionConflict: () =>
                              ref.invalidate(purchasesProvider),
                          onSubmit: (meta) async {
                            final ack = await ref
                                .read(apiLayerProvider)
                                .purchases
                                .setDayCorrection(
                                  book,
                                  dayId,
                                  open: !correctionOpen,
                                  meta: meta,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${AppStrings.serverReply} ${ack.id ?? ''}',
                                  ),
                                ),
                              );
                            }
                            ref.invalidate(purchasesProvider);
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        case _LedgerEntryLine(:final entry):
          final stripe =
              lines.whereType<_LedgerEntryLine>().toList().indexOf(line) % 2;
          final fill = stripe == 0
              ? look.card
              : (dark ? const Color(0xFF1C2433) : const Color(0xFFFFFBF3));
          scrollBands.add(
            KeyedSubtree(
              key: Key('purchase-entry-${entry.id}'),
              child: draft?.entryId == entry.id
                  ? _InlineLedgerRow(
                      key: ValueKey('edit-${entry.id}'),
                      book: book,
                      version: entry.dayVersion,
                      money: money,
                      scale: scale,
                      actionWidth: actionW,
                      entry: entry,
                    )
                  : band(
                      height: rowH,
                      color: fill,
                      lineColor: _gridLine(context),
                      cellKey: Key('purchase-grid-cell-${entry.id}'),
                      cells: dataCells(line, look.ink),
                      tail: _writable(entry)
                          ? Theme(
                              data: Theme.of(context).copyWith(
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GatedButton(
                                    buttonKey: Key('edit-${entry.id}'),
                                    allowed: true,
                                    online: online,
                                    filled: false,
                                    glyph: Icons.edit_outlined,
                                    label: AppStrings.edit,
                                    onPressed: () =>
                                        ref
                                            .read(_ledgerDraftProvider.notifier)
                                            .state = _LedgerDraft(
                                          entryId: entry.id,
                                        ),
                                  ),
                                  Expanded(
                                    child: GuardedMutation(
                                      buttonKey: Key('delete-${entry.id}'),
                                      inputs:
                                          'delete:${entry.id}:${entry.dayVersion}:${entry.version}',
                                      expectedVersion: entry.dayVersion,
                                      label: AppStrings.delete,
                                      glyph: Icons.delete_outline,
                                      filled: false,
                                      destructive: true,
                                      confirmText: AppStrings.confirmDelete,
                                      onSubmit: (meta) => _deleteEntry(
                                        context,
                                        ref,
                                        entry,
                                        meta,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
            ),
          );
      }
    }

    if (draft != null && draft.entryId == null && openDay != null) {
      scrollBands.add(
        _InlineLedgerRow(
          key: const ValueKey('purchase-inline-new'),
          book: book,
          version: openDay!.version,
          money: money,
          scale: scale,
          actionWidth: actionW,
        ),
      );
    }

    return _LedgerScroller(
      headerHeight: headerH,
      gold: gold,
      header: scrollBands.first,
      rows: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: scrollBands.skip(1).toList(),
      ),
    );
  }
}

/// Column titles stay pinned while the page scrolls. The header and the
/// rows share one horizontal offset.
class _LedgerScroller extends StatefulWidget {
  const _LedgerScroller({
    required this.headerHeight,
    required this.gold,
    required this.header,
    required this.rows,
  });

  final double headerHeight;
  final Color gold;
  final Widget header;
  final Widget rows;

  @override
  State<_LedgerScroller> createState() => _LedgerScrollerState();
}

class _LedgerScrollerState extends State<_LedgerScroller> {
  final _head = ScrollController();
  final _body = ScrollController();
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => _copy(_body, _head));
    _head.addListener(() => _copy(_head, _body));
  }

  void _copy(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if ((to.offset - target).abs() < 0.5) return;
    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  @override
  void dispose() {
    _head.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _FixedHead(
            height: widget.headerHeight,
            child: DecoratedBox(
              key: const Key('purchase-ledger'),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border(
                  top: BorderSide(color: widget.gold, width: 1.4),
                  left: BorderSide(color: widget.gold, width: 1.4),
                  right: BorderSide(color: widget.gold, width: 1.4),
                ),
              ),
              child: SingleChildScrollView(
                controller: _head,
                scrollDirection: Axis.horizontal,
                child: widget.header,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: widget.gold, width: 1.4),
            ),
            child: SingleChildScrollView(
              key: const Key('purchase-ledger-scroll'),
              controller: _body,
              scrollDirection: Axis.horizontal,
              child: widget.rows,
            ),
          ),
        ),
      ],
    );
  }
}

class _FixedHead extends SliverPersistentHeaderDelegate {
  _FixedHead({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _FixedHead oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

Future<String?> _deleteEntry(
  BuildContext context,
  WidgetRef ref,
  PurchaseEntryDto entry,
  MutationMeta meta,
) async {
  final book = ref.read(purchaseBookProvider);
  try {
    final ack = await ref
        .read(apiLayerProvider)
        .purchases
        .delete(book, entry.id, meta, entryVersion: entry.version);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
      );
    }
    ref.invalidate(purchasesProvider);
    return null;
  } catch (error) {
    return failureText(ref.read(errorHandlerProvider).toFailure(error));
  }
}
