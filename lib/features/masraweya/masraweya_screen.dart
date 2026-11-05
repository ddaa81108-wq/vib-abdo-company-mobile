import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/section_kit.dart';
import '../../ui/widgets/mutation_form.dart';

/// المصراوية redesigned to match Ali's website cards (2026-11-05).
class MasraweyaScreen extends ConsumerWidget {
  const MasraweyaScreen({super.key});

  static const screenKey = Key('screen-masraweya');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.masraweya)) {
      return const ForbiddenPane();
    }
    final day = ref.watch(masraweyaProvider);
    final money = ref.watch(apiLayerProvider).money;
    final canWrite = permissions.canWrite(SectionKey.masraweya);
    final online = ref.watch(onlineProvider);
    // Keyboard must not push/jump the page (Ali).
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(viewInsets: EdgeInsets.zero),
      child: SectionTheme(
        child: ListView(
          key: screenKey,
          padding: pagePadding(MediaQuery.sizeOf(context).width),
          children: [
            day.when(
              loading: () => const SkeletonBox(height: 120),
              error: (error, _) => presentFailure(
                ref.read(errorHandlerProvider).toFailure(error),
                onRetry: () => ref.invalidate(masraweyaProvider),
              ),
              data: (data) => _DayView(
                data: data,
                money: money,
                canWrite: canWrite,
                online: online,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _MText {
  static const page = 'صفحة المصراوية';
  static const currentDayChip = 'يوم العمل الحالي';
  static const todayChip = 'اليوم الحالي';
  static const workDate = 'تاريخ العمل';
  static const summary = 'ملخص اليوم';
  static const summaryNote = 'القيم بالجنيه المصري';
  static const box = 'المصراوية';
  static const purchasesToday = 'مشتريات اليوم';
  static const purchasesHint = 'أدخل المبلغ هنا';
  static const workToday = 'إجمالي شغل اليوم';
  static const workHint = 'القيم والعمولات';
  static const remaining = 'الرصيد المتبقي';
  static const remainingHint = 'السابق + المشتريات − الشغل';
  static const work = 'شغل اليوم';
  static const workFormula = 'القيمة + العمولة = الناتج';
  static const seq = 'التسلسل';
  static const value = 'القيمة';
  static const commission = 'العمولة';
  static const result = 'الناتج';
  static const noRows = 'لا توجد صفوف لهذا اليوم.';
  static const status = 'حالة اليوم';
  static const addRow = '+ صف';
  static const foot =
      'محفوظ بعد الحفظ • بداية اليوم ٥ صباحاً • تعديل آخر ٧ أيام لمن لديه صلاحية الكتابة';
  static const savedHint = 'احفظ بعد التعديل';
  static const dateReadOnly =
      'يوم العمل الحالي من الخادم فقط (لا يوجد اختيار يوم آخر).';
}

const _goldFill = sectionButtonGold;
const _goldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFD54F), Color(0xFFF5C02E), Color(0xFFE0A800)],
);

class _DayView extends ConsumerStatefulWidget {
  const _DayView({
    required this.data,
    required this.money,
    required this.canWrite,
    required this.online,
  });

  final MasraweyaDayDto data;
  final MoneyFormatter money;
  final bool canWrite;
  final bool online;

  @override
  ConsumerState<_DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<_DayView> {
  TextEditingController? _previous;
  TextEditingController? _purchases;
  List<_EntryFields> _rows = const [];
  final List<FocusNode> _foci = [];
  String? _boundDate;

  MasraweyaDayDto get data => widget.data;
  MoneyFormatter get money => widget.money;
  bool get canWrite => widget.canWrite;

  String _egp(MoneyValue? units) => money.formatOrDash(units, Currency.egp);

  @override
  void initState() {
    super.initState();
    if (canWrite) _bind(data);
  }

  @override
  void didUpdateWidget(covariant _DayView old) {
    super.didUpdateWidget(old);
    if (!canWrite) {
      _disposeEdit();
      return;
    }
    // Keep typed values across a version conflict (same as the old form).
    if (_previous == null || data.businessDate != _boundDate) {
      _bind(data);
    }
  }

  void _bind(MasraweyaDayDto day) {
    _disposeEdit();
    _previous = TextEditingController(text: _digits(day.previousValueUnits));
    _purchases = TextEditingController(text: _digits(day.purchasesUnits));
    _rows = [
      for (final entry in day.entries)
        _EntryFields(
          value: entry.valueUnits,
          commission: entry.commissionUnits,
        ),
    ];
    if (_rows.isEmpty) _rows = [_EntryFields()];
    _rebuildFoci();
    _previous!.addListener(_changed);
    _purchases!.addListener(_changed);
    for (final row in _rows) {
      row.value.addListener(_changed);
      row.commission.addListener(_changed);
    }
    _boundDate = day.businessDate;
  }

  void _rebuildFoci() {
    for (final n in _foci) {
      n.dispose();
    }
    _foci
      ..clear()
      ..addAll(List.generate(_rows.length * 2, (_) => FocusNode()));
  }

  void _changed() => setState(() {});

  void _disposeEdit() {
    _previous?.removeListener(_changed);
    _purchases?.removeListener(_changed);
    _previous?.dispose();
    _purchases?.dispose();
    for (final row in _rows) {
      row.value.removeListener(_changed);
      row.commission.removeListener(_changed);
      row.dispose();
    }
    for (final n in _foci) {
      n.dispose();
    }
    _foci.clear();
    _rows = const [];
    _previous = null;
    _purchases = null;
    _boundDate = null;
  }

  @override
  void dispose() {
    _disposeEdit();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      final row = _EntryFields();
      row.value.addListener(_changed);
      row.commission.addListener(_changed);
      _rows = [..._rows, row];
      _rebuildFoci();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_foci.length >= 2) _foci[_foci.length - 2].requestFocus();
    });
  }

  void _focusNext(int index) {
    final next = index + 1;
    if (next < _foci.length) {
      _foci[next].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = _pageCard(context);
    final summary = _summaryCard(context);
    final work = _workCard(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        page,
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 3, child: work),
            ],
          )
        else ...[
          // Image 3 stacking: page → ملخص اليوم → شغل اليوم.
          // Fixed typing (viewInsets zero) still holds; table grows downward.
          summary,
          work,
        ],
        if (data.status != null && data.status!.isNotEmpty)
          SectionNote(
            '${_MText.status}: ${dayStatusLabel(data.status)}',
            key: const Key('masraweya-status'),
          ),
        _footBar(context),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// Thin gold-bordered white/dark card (the website look).
  Widget _goldCard({required Widget child, Key? key, EdgeInsetsGeometry? pad}) {
    final look = context.look;
    final gold = sectionGold(context);
    return Padding(
      key: key,
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: gold, width: 1.4),
        ),
        child: Padding(
          padding: pad ?? const EdgeInsetsDirectional.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }

  Widget _blackPill(String text) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: sectionGold(context).withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: cairo(15, 800, color: Colors.white)),
        ),
      ),
    ),
  );

  Widget _palePill(String text) {
    final look = context.look;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: look.glass
            ? sectionGold(context).withValues(alpha: 0.18)
            : const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: sectionGold(context).withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        child: Text(text, style: cairo(11.5, 800, color: look.ink)),
      ),
    );
  }

  Widget _goldOvalButton({
    required String label,
    required VoidCallback? onPressed,
    Key? key,
    IconData? icon,
  }) {
    return ConstrainedBox(
      key: key,
      constraints: const BoxConstraints(maxWidth: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              gradient: _goldGradient,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _goldFill.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: sectionButtonInk),
                      const SizedBox(width: 4),
                    ],
                    Text(label, style: cairo(13, 800, color: sectionButtonInk)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageCard(BuildContext context) {
    final look = context.look;
    return _goldCard(
      key: const Key('masraweya-page'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _blackPill(_MText.page),
              _palePill(_MText.currentDayChip),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_MText.workDate, style: cairo(12, 700, color: look.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
                child: Container(
                  key: const Key('masraweya-date'),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: look.card,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: look.cardBorder),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: LtrText(
                      data.businessDate,
                      style: cairo(15, 800, color: look.ink),
                    ),
                  ),
                ),
              ),
              _goldOvalButton(
                label: _MText.todayChip,
                onPressed: null, // already on current day; no other day API
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_MText.dateReadOnly, style: cairo(11, 600, color: look.muted)),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final look = context.look;
    final colors = context.statusColors;
    final remaining = data.remainingUnits;
    final remainingNegative =
        remaining != null && remaining.isValid && (remaining.units ?? 0) < 0;
    final remainingColor = remainingNegative
        ? colors.cashNegative
        : (Theme.of(context).extension<AppColors>()?.success ??
              colors.creditText);
    final mint = remainingNegative
        ? colors.cashNegative.withValues(alpha: 0.10)
        : const Color(0xFFDCF5E7);
    final mintDark = remainingNegative
        ? colors.cashNegative.withValues(alpha: 0.16)
        : const Color(0xFF1A3A2A);

    return _goldCard(
      key: const Key('masraweya-summary'),
      pad: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _blackPill(_MText.summary),
                      const SizedBox(height: 4),
                      Text(
                        _MText.summaryNote,
                        style: cairo(11.5, 500, color: look.muted),
                      ),
                    ],
                  ),
                ),
                if (canWrite)
                  KeyedSubtree(
                    key: const Key('edit-masraweya'),
                    child: _compact(
                      GuardedMutation(
                        buttonKey: const Key('save-masraweya'),
                        inputs: _inputs(),
                        expectedVersion:
                            ref
                                .watch(masraweyaProvider)
                                .asData
                                ?.value
                                .version ??
                            data.version,
                        label: AppStrings.save,
                        glyph: Icons.save_outlined,
                        confirmText: _ready ? AppStrings.saveDayConfirm : null,
                        normalizedValue: _ready ? _preview() : null,
                        onVersionConflict: () =>
                            ref.invalidate(masraweyaProvider),
                        onSubmit: _submit,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // مشاركة الصورة omitted (rule 4 — new feature).
          if (canWrite)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Text(
                _MText.savedHint,
                style: cairo(11, 600, color: look.muted),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          // Black header band: المصراوية + date (image 2).
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            color: const Color(0xFF0B0B0F),
            child: Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _MText.box,
                      style: cairo(14, 800, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: LtrText(
                      data.businessDate,
                      style: cairo(13, 700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canWrite) ...[
            _summaryEditRow(
              key: const Key('masraweya-previous'),
              fieldKey: const Key('masraweya-previous-field'),
              label: AppStrings.previousValue,
              // «من رصيد <date>» blocked — no previousBusinessDate.
              controller: _previous!,
            ),
            _summaryEditRow(
              key: const Key('masraweya-purchases'),
              fieldKey: const Key('masraweya-purchases-field'),
              label: _MText.purchasesToday,
              hint: _MText.purchasesHint,
              controller: _purchases!,
            ),
          ] else ...[
            _summaryPlainRow(
              key: const Key('masraweya-previous'),
              label: AppStrings.previousValue,
              value: _egp(data.previousValueUnits),
              boxed: true,
            ),
            _summaryPlainRow(
              key: const Key('masraweya-purchases'),
              label: _MText.purchasesToday,
              hint: _MText.purchasesHint,
              value: _egp(data.purchasesUnits),
              boxed: true,
            ),
          ],
          _summaryPlainRow(
            key: const Key('masraweya-work-total'),
            label: _MText.workToday,
            hint: _MText.workHint,
            value: _egp(data.workTotalUnits),
            boxed: false,
          ),
          Offstage(
            child: _summaryPlainRow(
              key: const Key('masraweya-adjustment'),
              label: AppStrings.adjustment,
              value: _egp(data.historicalAdjustmentUnits),
              boxed: false,
            ),
          ),
          // الرصيد المتبقي — mint row (image 2).
          Container(
            key: const Key('masraweya-remaining'),
            color: look.glass ? mintDark : mint,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _MText.remaining,
                          style: cairo(14, 800, color: remainingColor),
                        ),
                      ),
                      Text(
                        _MText.remainingHint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: cairo(11, 500, color: look.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: MoneyText(
                      _egp(data.remainingUnits),
                      style: context.textExtras.amountLarge.copyWith(
                        color: remainingColor,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canWrite) const SizedBox.shrink(key: Key('masraweya-form')),
        ],
      ),
    );
  }

  Widget _summaryEditRow({
    required Key key,
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    final look = context.look;
    final gold = sectionGold(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: look.cardBorder)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(14, 800, color: look.ink),
                ),
                if (hint != null)
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairo(11, 500, color: look.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: FigureRow.valueWidth * scale,
                minWidth: 64,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: look.card,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: gold.withValues(alpha: 0.85)),
                ),
                child: UnitsField(
                  key: fieldKey,
                  controller: controller,
                  label: '',
                  showHint: false,
                  dense: true,
                  scrollPadding: EdgeInsets.zero,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPlainRow({
    required Key key,
    required String label,
    required String value,
    String? hint,
    required bool boxed,
  }) {
    final look = context.look;
    final gold = sectionGold(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: look.cardBorder)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(14, 800, color: look.ink),
                ),
                if (hint != null)
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairo(11, 500, color: look.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: FigureRow.valueWidth * scale,
                minWidth: 64,
              ),
              child: Container(
                height: 40 * scale,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                decoration: boxed
                    ? BoxDecoration(
                        color: look.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: gold.withValues(alpha: 0.85)),
                      )
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MoneyText(
                    value,
                    style: context.textExtras.amount.copyWith(
                      color: look.ink,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workCard(BuildContext context) {
    final look = context.look;
    final rowCount = canWrite ? _rows.length : data.entries.length;
    return _goldCard(
      key: const Key('masraweya-work'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _blackPill(_MText.work),
                  const SizedBox(height: 4),
                  Text(
                    _MText.workFormula,
                    style: cairo(11.5, 500, color: look.muted),
                  ),
                ],
              ),
              if (canWrite)
                _goldOvalButton(
                  key: const Key('masraweya-add-row'),
                  label: _MText.addRow,
                  onPressed: widget.online ? _addRow : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _WorkTable(
            key: const Key('masraweya-work-table'),
            headers: const [
              _MText.seq,
              _MText.value,
              _MText.commission,
              _MText.result,
            ],
            footerLabel: _MText.workToday,
            footerValue: _egp(data.workTotalUnits),
            empty: rowCount == 0 ? _MText.noRows : null,
            rows: [
              for (var i = 0; i < rowCount; i++)
                [
                  _seqCell(context, '${i + 1}'),
                  if (canWrite)
                    KeyedSubtree(
                      key: Key('masraweya-entry-$i'),
                      child: _inputCell(
                        fieldKey: Key('masraweya-entry-value-field-$i'),
                        controller: _rows[i].value,
                        focusIndex: i * 2,
                      ),
                    )
                  else
                    KeyedSubtree(
                      key: Key('masraweya-entry-$i'),
                      child: _moneyCell(
                        context,
                        _egp(data.entries[i].valueUnits),
                      ),
                    ),
                  if (canWrite)
                    KeyedSubtree(
                      key: Key('masraweya-entry-commission-$i'),
                      child: _inputCell(
                        fieldKey: Key('masraweya-entry-commission-field-$i'),
                        controller: _rows[i].commission,
                        focusIndex: i * 2 + 1,
                      ),
                    )
                  else
                    KeyedSubtree(
                      key: Key('masraweya-entry-commission-$i'),
                      child: _moneyCell(
                        context,
                        _egp(data.entries[i].commissionUnits),
                      ),
                    ),
                  // الناتج: no server per-row result — dash (rule 4).
                  _moneyCell(context, AppStrings.dash),
                ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _seqCell(BuildContext context, String n) => Center(
    child: Text(n, style: cairo(14, 800, color: context.look.ink)),
  );

  Widget _moneyCell(BuildContext context, String value) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: MoneyText(value, style: cairo(13, 700, color: context.look.ink)),
    ),
  );

  Widget _inputCell({
    required Key fieldKey,
    required TextEditingController controller,
    required int focusIndex,
  }) {
    final look = context.look;
    final last = focusIndex >= _foci.length - 1;
    return Container(
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: look.cardBorder),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
      child: UnitsField(
        key: fieldKey,
        controller: controller,
        label: '',
        showHint: false,
        dense: true,
        focusNode: focusIndex < _foci.length ? _foci[focusIndex] : null,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        scrollPadding: EdgeInsets.zero,
        onSubmitted: (_) => _focusNext(focusIndex),
      ),
    );
  }

  Widget _footBar(BuildContext context) {
    final look = context.look;
    final gold = sectionGold(context);
    return Container(
      key: const Key('masraweya-foot'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.7)),
      ),
      child: Text(
        _MText.foot,
        textAlign: TextAlign.center,
        style: cairo(11, 600, color: look.muted),
      ),
    );
  }

  bool get _ready {
    if (_previous == null || _purchases == null) return false;
    return parseUnits(_previous!.text) != null &&
        parseUnits(_purchases!.text) != null &&
        _parsedEntries() != null;
  }

  String _inputs() {
    if (_previous == null || _purchases == null) return '';
    final rows = _rows
        .map((row) => '${row.value.text},${row.commission.text}')
        .join(';');
    return '${_previous!.text}|${_purchases!.text}|$rows';
  }

  List<MasraweyaEntryDto>? _parsedEntries() {
    final entries = <MasraweyaEntryDto>[];
    for (final row in _rows) {
      final value = parseUnits(row.value.text);
      final commission = parseUnits(row.commission.text);
      if (value == null || commission == null) return null;
      entries.add(
        MasraweyaEntryDto(
          valueUnits: MoneyValue.known(value),
          commissionUnits: MoneyValue.known(commission),
        ),
      );
    }
    return entries;
  }

  String _preview() {
    final previous = parseUnits(_previous!.text)!;
    final purchases = parseUnits(_purchases!.text)!;
    final entries = _parsedEntries()!;
    final parts = <String>['$previous', '$purchases'];
    for (final entry in entries) {
      parts.add('${entry.valueUnits?.asInt ?? ''}');
      parts.add('${entry.commissionUnits?.asInt ?? ''}');
    }
    return parts.join(' · ');
  }

  Future<String?> _submit(MutationMeta meta) async {
    final previous = parseUnits(_previous!.text);
    final purchases = parseUnits(_purchases!.text);
    final entries = _parsedEntries();
    if (previous == null || purchases == null || entries == null) {
      return AppStrings.integerOnly;
    }
    final saved = await ref
        .read(masraweyaActionsProvider)
        .saveDay(
          SaveMasraweyaDayRequest(
            businessDate: data.businessDate,
            previousValueUnits: previous,
            purchasesUnits: purchases,
            entries: entries,
          ),
          meta,
        );
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppStrings.serverReply} ${saved.version ?? ''}'),
      ),
    );
    ref.invalidate(masraweyaProvider);
    return null;
  }
}

/// Website-style work table: black header, growing rows, black footer.
class _WorkTable extends StatelessWidget {
  const _WorkTable({
    required this.headers,
    required this.rows,
    required this.footerLabel,
    required this.footerValue,
    this.empty,
    super.key,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final String footerLabel;
  final String footerValue;
  final String? empty;

  static const _flex = [2, 4, 4, 3];

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gold = sectionGold(context);
    final line = BorderSide(color: gold.withValues(alpha: 0.55));
    Widget cell(int i, Widget child, {Color? color, bool head = false}) =>
        Expanded(
          flex: _flex[i],
          child: Container(
            decoration: BoxDecoration(
              color: color,
              border: i == headers.length - 1
                  ? null
                  : Border(left: line), // visual divider (RTL-safe via Border)
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            alignment: Alignment.center,
            child: child,
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: gold.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0B0B0F)),
              child: Row(
                children: [
                  for (var i = 0; i < headers.length; i++)
                    cell(
                      i,
                      Text(
                        headers[i],
                        textAlign: TextAlign.center,
                        style: cairo(12, 800, color: Colors.white),
                      ),
                      head: true,
                    ),
                ],
              ),
            ),
            if (rows.isEmpty && empty != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(empty!, style: cairo(13, 600, color: look.muted)),
              )
            else
              for (var r = 0; r < rows.length; r++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: look.card,
                    border: Border(bottom: BorderSide(color: look.cardBorder)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < rows[r].length; i++)
                          cell(i, rows[r][i]),
                      ],
                    ),
                  ),
                ),
            DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0B0B0F)),
              child: Row(
                children: [
                  Expanded(
                    flex: _flex[0] + _flex[1] + _flex[2],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Text(
                        footerLabel,
                        style: cairo(12.5, 800, color: Colors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flex[3],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MoneyText(
                            footerValue,
                            style: cairo(13, 800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _compact(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(
      filledButtonTheme: FilledButtonThemeData(style: sectionIconButtonStyle()),
    ),
    child: child,
  ),
);

String _digits(MoneyValue? value) =>
    value != null && value.isValid ? '${value.units}' : '';

class _EntryFields {
  _EntryFields({MoneyValue? value, MoneyValue? commission})
    : value = TextEditingController(text: _digits(value)),
      commission = TextEditingController(text: _digits(commission));

  final TextEditingController value;
  final TextEditingController commission;

  void dispose() {
    value.dispose();
    commission.dispose();
  }
}
