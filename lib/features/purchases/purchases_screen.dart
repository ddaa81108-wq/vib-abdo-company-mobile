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

    return SectionTheme(
      child: ListView(
        key: screenKey,
        // One day's page: build it whole so the totals card at the end is
        // ready (and readable by tests) without scrolling.
        scrollCacheExtent: const ScrollCacheExtent.pixels(6000),
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          const SectionHeading(_PText.title),
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
          KeptData<PurchasesPage>(
            value: page,
            resetKey: book,
            onRetry: () => ref.invalidate(purchasesProvider),
            messageOf: (error) =>
                failureText(ref.read(errorHandlerProvider).toFailure(error)),
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
                  _OpeningCard(
                    book: book,
                    day: day,
                    money: money,
                    canWrite: canWrite,
                    online: online,
                  ),
                  if (empty)
                    const EmptyPane(
                      key: Key('purchases-empty'),
                      message: AppStrings.emptyPurchases,
                    ),
                  if (day != null)
                    _DayCard(
                      day: day,
                      entries: data.entries,
                      money: money,
                      canWrite: canWrite,
                      canFinalize: canFinalize,
                      online: online,
                      book: book,
                    )
                  else
                    for (final entry in data.entries)
                      _Entry(
                        entry: entry,
                        money: money,
                        book: book,
                        version: entry.dayVersion,
                        canWrite: false,
                        online: online,
                      ),
                  _RegisterTotals(totals: data.registerTotals, money: money),
                ],
              );
            },
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
  static String day(String n) => 'يوم #$n';
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
    required this.entries,
    required this.money,
    required this.canWrite,
    required this.canFinalize,
    required this.online,
    required this.book,
  });

  final PurchaseDayDto day;
  final List<PurchaseEntryDto> entries;
  final MoneyFormatter money;
  final bool canWrite;
  final bool canFinalize;
  final bool online;
  final PurchaseBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = day.numberLabel;
    final tone = dayToneIndex(label);
    final band = tone == null ? null : context.statusColors.dayTones[tone];
    final correctionOpen = day.correctionOpen;
    final editable = day.status == 'draft' || correctionOpen;
    final caption = vodafoneCaption(day.vodafoneRemainingUnits);
    String f(MoneyValue? v, Currency c) => money.formatOrDash(v, c);
    return Card(
      key: Key('purchase-day-$label'),
      color: band,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: context.look.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PillTitle(_PText.day(label)),
                _CorrectionStatus(day: label, open: correctionOpen),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            PairGrid(
              children: [
                EdgeSummary(
                  title: _PText.previousValue,
                  value: f(day.previousDebtUnits, Currency.lyd),
                  edge: _red(context),
                ),
                EdgeSummary(
                  title: _PText.workToday,
                  value: f(day.todayResultUnits, Currency.lyd),
                  edge: sectionGold(context),
                ),
                EdgeSummary(
                  title: _PText.paidTotal,
                  value: f(day.todayPaidUnits, Currency.lyd),
                  edge: _green(context),
                ),
                EdgeSummary(
                  title: AppStrings.totalDebt,
                  value: f(day.totalDebtUnits, Currency.lyd),
                  edge: _red(context),
                ),
              ],
            ),
            EdgeSummary(
              title: _PText.vodafoneOurs,
              value: f(day.vodafoneRemainingUnits, vodafoneCurrency),
              edge: _green(context),
              note: caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (canWrite && editable && day.version != null)
                  GatedButton(
                    buttonKey: ValueKey('add-purchase-$label'),
                    allowed: true,
                    online: online,
                    label: AppStrings.add,
                    onPressed: () => showAppForm<void>(
                      context,
                      // expectedDayVersion is the open day's version. A new
                      // row has no version yet; edit and delete send the
                      // entry's own version as expectedVersion.
                      _PurchaseForm(book: book, version: day.version),
                    ),
                  ),
                if (canFinalize && day.status == 'draft' && day.version != null)
                  GuardedMutation(
                    buttonKey: ValueKey('finalize-day-$label'),
                    inputs: 'finalize:$label:${day.version}',
                    expectedVersion: day.version,
                    label: AppStrings.finalizeDay,
                    confirmText: AppStrings.finalizeConfirm,
                    onSubmit: (meta) => _finalize(context, ref, meta),
                  ),
                if (canFinalize && day.status == 'finalized' && !correctionOpen)
                  GuardedMutation(
                    buttonKey: Key('open-correction-$label'),
                    inputs: 'open-correction:$label:${day.version}',
                    expectedVersion: day.version,
                    label: AppStrings.openDayCorrection,
                    confirmText: AppStrings.openCorrectionConfirm,
                    onVersionConflict: () => ref.invalidate(purchasesProvider),
                    onSubmit: (meta) =>
                        _correct(context, ref, meta, open: true),
                  ),
                if (canFinalize && correctionOpen)
                  GuardedMutation(
                    buttonKey: Key('close-correction-$label'),
                    inputs: 'close-correction:$label:${day.version}',
                    expectedVersion: day.version,
                    label: AppStrings.closeDayCorrection,
                    confirmText: AppStrings.closeCorrectionConfirm,
                    onVersionConflict: () => ref.invalidate(purchasesProvider),
                    onSubmit: (meta) =>
                        _correct(context, ref, meta, open: false),
                  ),
              ],
            ),
            for (var i = 0; i < entries.length; i++)
              _Entry(
                entry: entries[i],
                seq: i + 1,
                money: money,
                book: book,
                // The write names this row's day, not the open day's version.
                version: entries[i].dayVersion,
                canWrite:
                    canWrite &&
                    editable &&
                    entries[i].dayId == day.id &&
                    entries[i].dayVersion != null,
                online: online,
              ),
          ],
        ),
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

class _Entry extends ConsumerWidget {
  const _Entry({
    required this.entry,
    required this.money,
    required this.book,
    required this.version,
    required this.canWrite,
    required this.online,
    this.seq,
  });

  final PurchaseEntryDto entry;
  final MoneyFormatter money;
  final PurchaseBook book;
  final int? version;
  final bool canWrite;
  final bool online;
  final int? seq;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = context.look;
    Widget cell(String label, Widget value, {Color? tint}) => Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.14) ?? look.strip,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: tint ?? look.cardBorder),
      ),
      child: Column(
        children: [
          Text(label, style: cairo(11, 700, color: look.muted)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: value),
        ],
      ),
    );
    final figure = context.textExtras.amount.copyWith(
      fontSize: 14,
      color: look.ink,
    );
    Widget amount(MoneyValue? v, Currency c) =>
        MoneyText(money.formatOrDash(v, c), style: figure);
    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(child: cells[i]),
          ],
        ],
      ),
    );
    return Padding(
      key: Key('purchase-entry-${entry.id}'),
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: look.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (seq != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: Text(
                        '$seq',
                        style: cairo(14, 800, color: look.muted),
                      ),
                    ),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _red(context).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _red(context).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        child: Text(
                          entry.itemLabel ?? AppStrings.dash,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cairo(12.5, 800, color: _red(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              row([
                cell(
                  AppStrings.egpValue,
                  amount(entry.egpValueUnits, Currency.egp),
                ),
                cell(
                  _PText.operation,
                  Text(
                    calculationLabel(entry.calculationMode),
                    style: cairo(13, 800, color: look.ink),
                  ),
                ),
                cell(
                  _PText.rate,
                  LtrText(
                    entry.exchangeRate == null
                        ? AppStrings.dash
                        : money.formatDecimal(entry.exchangeRate!),
                    style: figure,
                  ),
                ),
              ]),
              row([
                cell(_PText.result, amount(entry.resultUnits, Currency.lyd)),
                cell(AppStrings.paid, amount(entry.paidUnits, Currency.lyd)),
                cell(
                  _PText.remaining,
                  amount(entry.remainingUnits, Currency.lyd),
                  tint: _amber(context),
                ),
              ]),
              if (canWrite) ...[
                const SizedBox(height: AppSpacing.xs),
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
                      inputs: 'delete:${entry.id}:$version:${entry.version}',
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
}
