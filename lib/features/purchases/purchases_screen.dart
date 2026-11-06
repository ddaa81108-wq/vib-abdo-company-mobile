import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
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
import '../../ui/widgets/section_kit.dart';
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

    final look = context.look;
    final gold = _frameGold(context);
    return SectionTheme(
      child: ListView(
        key: screenKey,
        // One page: build it whole so the totals card at the end is ready
        // (and readable by tests) without scrolling.
        scrollCacheExtent: const ScrollCacheExtent.pixels(6000),
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          const SectionHeading(_PText.title),
          DecoratedBox(
            decoration: BoxDecoration(
              color: look.card,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: gold, width: 1.6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: sectionStripGradient,
                    ),
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<PurchaseBook>(
                          key: const Key('purchase-books'),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF111111);
                              }
                              return const Color(0xFF3A3F4B);
                            }),
                            foregroundColor: const WidgetStatePropertyAll(
                              sectionStripInk,
                            ),
                            side: WidgetStatePropertyAll(
                              BorderSide(color: gold.withValues(alpha: 0.9)),
                            ),
                            shape: const WidgetStatePropertyAll(
                              StadiumBorder(),
                            ),
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
                              ref.read(purchaseBookProvider.notifier).state =
                                  value.first,
                        ),
                      ),
                    ),
                  ),
                  KeptData<PurchasesPage>(
                    value: page,
                    resetKey: book,
                    onRetry: () => ref.invalidate(purchasesProvider),
                    messageOf: (error) => failureText(
                      ref.read(errorHandlerProvider).toFailure(error),
                    ),
                    failureOf: (error) =>
                        ref.read(errorHandlerProvider).toFailure(error),
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
                      final empty = day == null && data.entries.isEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (day != null)
                            _DayCard(
                              day: day,
                              money: money,
                              canWrite: canWrite,
                              canFinalize: canFinalize,
                              online: online,
                              book: book,
                            ),
                          if (empty)
                            const EmptyPane(
                              key: Key('purchases-empty'),
                              message: AppStrings.emptyPurchases,
                            ),
                          if (data.entries.isNotEmpty)
                            _PurchaseGrid(
                              entries: data.entries,
                              money: money,
                              book: book,
                              openDay: day,
                              canWrite: canWrite,
                              online: online,
                            ),
                          _OpeningCard(
                            book: book,
                            day: day,
                            money: money,
                            canWrite: canWrite,
                            online: online,
                          ),
                          _RegisterTotals(
                            totals: data.registerTotals,
                            money: money,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The website's words for المشتريات (display only).
abstract final class _PText {
  static const title = 'قسم المشتريات';
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

Color _red(BuildContext c) => c.statusColors.debtText;
Color _green(BuildContext c) => c.statusColors.creditText;
Color _amber(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFFFBBF24)
    : const Color(0xFFB45309);

/// Light-mode [sectionGold] is orange. The statement frame uses button gold.
Color _frameGold(BuildContext context) =>
    context.look.glass ? sectionGold(context) : sectionButtonGold;

Widget _goldAdd(BuildContext context, Widget child) {
  return Theme(
    data: Theme.of(context).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sectionButtonGold,
          foregroundColor: sectionButtonInk,
          disabledBackgroundColor: sectionButtonGold.withValues(alpha: 0.38),
          disabledForegroundColor: sectionButtonInk.withValues(alpha: 0.7),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
        ),
      ),
    ),
    child: child,
  );
}

Widget _greenFinalize(BuildContext context, Widget child) {
  const green = Color(0xFF15803D);
  return Theme(
    data: Theme.of(context).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: green.withValues(alpha: 0.38),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
        ),
      ),
    ),
    child: child,
  );
}

class _RegisterTotals extends StatelessWidget {
  const _RegisterTotals({required this.totals, required this.money});

  final PurchasesRegisterTotalsDto? totals;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    String f(MoneyValue? v, Currency c) => money.formatOrDash(v, c);
    return SectionCard(
      key: const Key('purchases-lifetime'),
      title: _PText.lifetime,
      child: PairGrid(
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
            title: _PText.lifeRemaining,
            value: f(totals?.remainingUnits, Currency.lyd),
            edge: _red(context),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final redFill = dark ? const Color(0xFF3F1D1D) : const Color(0xFFFEE2E2);
    final redInk = dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    final blackFill = dark ? const Color(0xFF0B0B0F) : const Color(0xFF111111);
    const blackInk = Color(0xFFF5F5F4);
    final cream = dark ? const Color(0xFF14261C) : const Color(0xFFF3F7E8);
    final greenInk = dark ? const Color(0xFF86EFAC) : const Color(0xFF166534);
    return Padding(
      key: Key('purchase-day-$label'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              if (showAdd)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: _goldAdd(
                      context,
                      GatedButton(
                        buttonKey: ValueKey('add-purchase-$label'),
                        allowed: true,
                        online: online,
                        leading: Icons.add,
                        label: _PText.addDeal,
                        onPressed: () => showAppForm<void>(
                          context,
                          // expectedDayVersion is the open day's version. A new
                          // row has no version yet; edit and delete send the
                          // entry's own version as expectedVersion.
                          _PurchaseForm(book: book, version: day.version),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: AppSpacing.sm),
              if (showFinalize)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: _greenFinalize(
                      context,
                      GuardedMutation(
                        buttonKey: ValueKey('finalize-day-$label'),
                        inputs: 'finalize:$label:${day.version}',
                        expectedVersion: day.version,
                        label: AppStrings.finalizeDay,
                        confirmText: AppStrings.finalizeConfirm,
                        onSubmit: (meta) => _finalize(context, ref, meta),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CorrectionStatus(day: label, open: correctionOpen),
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
          const SizedBox(height: AppSpacing.sm),
          _totalPair(
            context,
            _TotalTile(
              tileKey: const Key('purchase-total-previous'),
              label: _PText.previousValue,
              value: f(day.previousDebtUnits, Currency.lyd),
              fill: redFill,
              ink: redInk,
              border: redInk.withValues(alpha: 0.45),
            ),
            _TotalTile(
              tileKey: const Key('purchase-total-work'),
              label: _PText.workToday,
              value: f(day.todayResultUnits, Currency.lyd),
              fill: blackFill,
              ink: blackInk,
              border: _frameGold(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _totalPair(
            context,
            _TotalTile(
              tileKey: const Key('purchase-total-paid'),
              label: _PText.paidTotal,
              value: f(day.todayPaidUnits, Currency.lyd),
              fill: blackFill,
              ink: blackInk,
              border: _frameGold(context),
            ),
            _TotalTile(
              tileKey: const Key('purchase-total-debt'),
              label: AppStrings.totalDebt,
              value: f(day.totalDebtUnits, Currency.lyd),
              fill: redFill,
              ink: redInk,
              border: redInk.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TotalTile(
            tileKey: const Key('purchase-vodafone-ours'),
            label: _PText.vodafoneOurs,
            value: f(day.vodafoneRemainingUnits, vodafoneCurrency),
            fill: cream,
            ink: greenInk,
            border: greenInk.withValues(alpha: 0.45),
            note: owed ? caption : null,
            wide: true,
          ),
        ],
      ),
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
      _prefill(_egp, entry.egpValueUnits);
      _prefill(_paid, entry.paidUnits);
      _prefill(_vodafone, entry.vodafoneConsumedUnits);
      if (entry.exchangeRate != null) _rate.text = entry.exchangeRate!.value;
      if (entry.calculationMode != null) _mode = entry.calculationMode!;
    }
    for (final controller in [_egp, _rate, _paid, _vodafone, _customLabel]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

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
      ref.invalidate(purchasesProvider);
      Navigator.of(context).pop();
      return null;
    } catch (error) {
      return failureText(ref.read(errorHandlerProvider).toFailure(error));
    }
  }
}

/// Opening is a write on an open day that has a version. A missing day, a
/// day with no version, or a finalized day whose correction is closed, does
/// not offer the button.
bool _openingWritable(PurchaseDayDto? day) {
  if (day == null || day.version == null) return false;
  return day.status == 'draft' || day.correctionOpen;
}

class _OpeningCard extends StatelessWidget {
  const _OpeningCard({
    required this.book,
    required this.day,
    required this.money,
    required this.canWrite,
    required this.online,
  });

  final PurchaseBook book;
  final PurchaseDayDto? day;
  final MoneyFormatter money;
  final bool canWrite;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      key: const Key('opening-card'),
      title: AppStrings.purchaseOpening,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FigureBox(
            rows: [
              FigureRow(
                label: AppStrings.previousDebt,
                value: money.formatOrDash(day?.previousDebtUnits, Currency.lyd),
              ),
              FigureRow(
                label: AppStrings.previousVodafone,
                value: money.formatOrDash(
                  day?.previousVodafoneUnits,
                  vodafoneCurrency,
                ),
                last: true,
              ),
            ],
          ),
          if (canWrite && _openingWritable(day)) ...[
            const SizedBox(height: AppSpacing.sm),
            GatedButton(
              buttonKey: const Key('set-opening'),
              allowed: true,
              online: online,
              label: AppStrings.purchaseOpening,
              onPressed: () => showAppForm<void>(
                context,
                _OpeningForm(book: book, day: day),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpeningForm extends ConsumerStatefulWidget {
  const _OpeningForm({required this.book, required this.day});

  final PurchaseBook book;
  final PurchaseDayDto? day;

  @override
  ConsumerState<_OpeningForm> createState() => _OpeningFormState();
}

class _OpeningFormState extends ConsumerState<_OpeningForm> {
  final _debt = TextEditingController();
  final _vodafone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final debt = widget.day?.previousDebtUnits;
    final vodafone = widget.day?.previousVodafoneUnits;
    if (debt != null && debt.isValid) _debt.text = '${debt.units}';
    if (vodafone != null && vodafone.isValid) {
      _vodafone.text = '${vodafone.units}';
    }
    for (final controller in [_debt, _vodafone]) {
      controller.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_debt, _vodafone]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debt = parseUnits(_debt.text);
    final vodafone = parseUnits(_vodafone.text);
    final valid = debt != null && vodafone != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.purchaseOpening,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(AppStrings.noPreview),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('opening-debt'),
          controller: _debt,
          label: AppStrings.previousDebt,
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('opening-vodafone'),
          controller: _vodafone,
          label: AppStrings.previousVodafone,
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-opening'),
          inputs: '${_debt.text}|${_vodafone.text}|${widget.day?.version}',
          expectedVersion: widget.day?.version,
          label: AppStrings.saveOpening,
          confirmText: valid ? AppStrings.openingConfirm : null,
          normalizedValue: valid ? '$debt · $vodafone' : null,
          onVersionConflict: () => ref.invalidate(purchasesProvider),
          onSubmit: (meta) => _submit(meta, debt, vodafone),
        ),
      ],
    );
  }

  Future<String?> _submit(MutationMeta meta, int? debt, int? vodafone) async {
    if (debt == null || vodafone == null) return AppStrings.integerOnly;
    final ack = await ref
        .read(apiLayerProvider)
        .purchases
        .setOpening(
          widget.book,
          previousDebtUnits: debt,
          previousVodafoneUnits: vodafone,
          meta: meta,
        );
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppStrings.serverReply} ${ack.id ?? ''}')),
    );
    ref.invalidate(purchasesProvider);
    // The confirm dialog is the top route. Close this form after it pops.
    final navigator = Navigator.of(context);
    final formRoute = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (formRoute != null && formRoute.isActive) {
        navigator.removeRoute(formRoute);
      }
    });
    return null;
  }
}

class _CorrectionStatus extends StatelessWidget {
  const _CorrectionStatus({required this.day, required this.open});

  final String day;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final background = open ? colors.chipReviewBg : colors.chipNormalBg;
    final foreground = open ? colors.chipReviewFg : colors.chipNormalFg;
    final label = open
        ? AppStrings.correctionOpen
        : AppStrings.correctionClosed;
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
    required this.fill,
    required this.ink,
    required this.border,
    this.note,
    this.wide = false,
  });

  final Key tileKey;
  final String label;
  final String value;
  final Color fill;
  final Color ink;
  final Color border;
  final String? note;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: cairo(13, 800, color: ink),
          ),
          if (note != null)
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairo(11, 600, color: ink),
            ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              value,
              style: context.textExtras.amount.copyWith(
                color: ink,
                fontSize: wide ? 22 : 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _totalPair(BuildContext context, Widget right, Widget left) {
  return IntrinsicHeight(
    child: Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: right),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: left),
      ],
    ),
  );
}

const _ledgerCols = <(String, double)>[
  (_PText.colSeq, 56),
  (_PText.colKind, 136),
  (_PText.colValue, 136),
  (_PText.operation, 76),
  (_PText.rate, 88),
  (_PText.result, 124),
  (AppStrings.paid, 120),
  (_PText.remaining, 120),
  (AppStrings.vodafoneConsumed, 156),
];

const _ledgerActionWidth = 128.0;
const _ledgerHeaderH = 48.0;
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
  const _LedgerBreakLine({required this.dayId, required this.closing});
  final String dayId;
  final MoneyValue? closing;
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
    required this.online,
  });

  final List<PurchaseEntryDto> entries;
  final MoneyFormatter money;
  final PurchaseBook book;
  final PurchaseDayDto? openDay;
  final bool canWrite;
  final bool online;

  bool _writable(PurchaseEntryDto entry) {
    final day = openDay;
    if (!canWrite || day == null) return false;
    final editable = day.status == 'draft' || day.correctionOpen;
    return editable && entry.dayId == day.id && entry.dayVersion != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
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
      Widget? tail,
      Border? border,
    }) {
      return DecoratedBox(
        decoration: BoxDecoration(color: color, border: border),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _ledgerCols.length; i++)
              SizedBox(
                width: _ledgerCols[i].$2 * scale,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Align(
                    alignment: Alignment.center,
                    child: cells[i],
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: actionW,
                maxWidth: actionW,
                minHeight: height,
              ),
              child: tail ?? const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    final scrollBands = <Widget>[
      band(
        height: headerH,
        color: headerFill,
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
        case _LedgerBreakLine(:final dayId, :final closing):
          final label = Text(
            _PText.lastRemaining,
            style: cairo(13, 800, color: breakInk),
          );
          scrollBands.add(
            SizedBox(
              key: Key('purchase-rollover-$dayId'),
              height: breakH,
              width: _ledgerCols.fold<double>(
                    0,
                    (sum, col) => sum + col.$2 * scale,
                  ) +
                  actionW,
              child: ColoredBox(
                color: breakFill,
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const SizedBox(width: 12),
                    label,
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(
                          money.formatOrDash(closing, Currency.lyd),
                          style: figure.copyWith(color: breakInk),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        case _LedgerEntryLine(:final entry):
          final stripe = lines.whereType<_LedgerEntryLine>().toList().indexOf(
                line,
              ) %
              2;
          final fill = stripe == 0
              ? look.card
              : (dark ? const Color(0xFF1C2433) : const Color(0xFFFFFBF3));
          scrollBands.add(
            KeyedSubtree(
              key: Key('purchase-entry-${entry.id}'),
              child: band(
                height: rowH,
                color: fill,
                border: Border(
                  top: BorderSide(color: gold.withValues(alpha: 0.35)),
                ),
                cells: dataCells(line, look.ink),
                tail: _writable(entry)
                    ? Row(
                        children: [
                          GatedButton(
                            buttonKey: Key('edit-${entry.id}'),
                            allowed: true,
                            online: online,
                            filled: false,
                            glyph: Icons.check,
                            label: AppStrings.edit,
                            onPressed: () => showAppForm<void>(
                              context,
                              _PurchaseForm(
                                book: book,
                                version: entry.dayVersion,
                                entry: entry,
                              ),
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
                              onSubmit: (meta) =>
                                  _deleteEntry(context, ref, entry, meta),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          );
      }
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        key: const Key('purchase-ledger'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: gold, width: 1.4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SingleChildScrollView(
            key: const Key('purchase-ledger-scroll'),
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: scrollBands,
            ),
          ),
        ),
      ),
    );
  }
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
