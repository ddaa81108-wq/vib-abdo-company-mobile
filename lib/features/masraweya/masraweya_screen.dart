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
    return SectionTheme(
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
    );
  }
}

/// The website's words for المصراوية (display only).
abstract final class _MText {
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
  static const workNote = 'القيمة + العمولة = الناتج';
  static const seq = 'التسلسل';
  static const value = 'القيمة';
  static const commission = 'العمولة';
  static const noRows = 'لا توجد صفوف لهذا اليوم.';
  static const status = 'حالة اليوم';
  static const page = 'صفحة المصراوية';
  static const addRow = 'إضافة صف';
  static const currentDayChip = 'يوم العمل الحالي';
  static const workDate = 'تاريخ العمل';
  static const result = 'الناتج';
}

class _DayView extends StatelessWidget {
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

  String _egp(MoneyValue? units) => money.formatOrDash(units, Currency.egp);

  @override
  Widget build(BuildContext context) {
    final success =
        Theme.of(context).extension<AppColors>()?.success ??
        context.statusColors.creditText;
    final adjustment = data.historicalAdjustmentUnits;
    final look = context.look;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // صفحة المصراوية: the server's business day (the app reads only the
        // current day; no date picker in the API layer).
        SectionCard(
          title: _MText.page,
          trailing: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: sectionGold(context).withValues(alpha: 0.16),
              border: Border.all(
                color: sectionGold(context).withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              child: Text(
                _MText.currentDayChip,
                style: cairo(11.5, 800, color: look.ink),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_MText.workDate, style: cairo(13, 700, color: look.ink)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                key: const Key('masraweya-date'),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: look.card,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: sectionGold(context).withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: look.muted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: LtrText(
                          data.businessDate,
                          style: cairo(15, 800, color: look.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: _MText.summary,
          note: _MText.summaryNote,
          trailing: canWrite
              ? _compact(
                  GatedButton(
                    buttonKey: const Key('edit-masraweya'),
                    allowed: true,
                    online: online,
                    label: AppStrings.save,
                    glyph: Icons.edit_outlined,
                    onPressed: () =>
                        showAppForm<void>(context, _MasraweyaForm(day: data)),
                  ),
                )
              : null,
          child: FigureBox(
            title: _MText.box,
            trailing: data.businessDate,
            rows: [
              FigureRow(
                key: const Key('masraweya-previous'),
                label: AppStrings.previousValue,
                value: _egp(data.previousValueUnits),
                boxed: true,
              ),
              FigureRow(
                key: const Key('masraweya-purchases'),
                label: _MText.purchasesToday,
                hint: _MText.purchasesHint,
                value: _egp(data.purchasesUnits),
                boxed: true,
              ),
              FigureRow(
                key: const Key('masraweya-work-total'),
                label: _MText.workToday,
                hint: _MText.workHint,
                value: _egp(data.workTotalUnits),
              ),
              if (adjustment != null &&
                  !(adjustment.isValid && adjustment.units == 0))
                FigureRow(
                  key: const Key('masraweya-adjustment'),
                  label: AppStrings.adjustment,
                  value: _egp(adjustment),
                )
              else
                Offstage(
                  child: FigureRow(
                    key: const Key('masraweya-adjustment'),
                    label: AppStrings.adjustment,
                    value: _egp(adjustment),
                  ),
                ),
              FigureRow(
                key: const Key('masraweya-remaining'),
                label: _MText.remaining,
                hint: _MText.remainingHint,
                value: _egp(data.remainingUnits),
                highlight: success,
                last: true,
              ),
            ],
          ),
        ),
        SectionCard(
          title: _MText.work,
          note: _MText.workNote,
          // + صف: opens the day form with one more empty row; saved with the
          // same PUT /api/masraweya/day entries list (Ali, 2026-11-04).
          trailing: canWrite
              ? _compact(
                  GatedButton(
                    buttonKey: const Key('masraweya-add-row'),
                    allowed: true,
                    online: online,
                    label: _MText.addRow,
                    glyph: Icons.add_rounded,
                    onPressed: () => showAppForm<void>(
                      context,
                      _MasraweyaForm(day: data, addRow: true),
                    ),
                  ),
                )
              : null,
          child: GridTable(
            numericFrom: 1,
            footerFlex: const [10, 3],
            // الناتج: no per-row result from the server, so a dash (no
            // device arithmetic).
            headers: const [
              _MText.seq,
              _MText.value,
              _MText.commission,
              _MText.result,
            ],
            flex: const [2, 4, 4, 3],
            empty: _MText.noRows,
            rows: [
              for (var i = 0; i < data.entries.length; i++)
                [
                  gridText(context, '${i + 1}', bold: true),
                  KeyedSubtree(
                    key: Key('masraweya-entry-$i'),
                    child: gridMoney(context, _egp(data.entries[i].valueUnits)),
                  ),
                  KeyedSubtree(
                    key: Key('masraweya-entry-commission-$i'),
                    child: gridMoney(
                      context,
                      _egp(data.entries[i].commissionUnits),
                    ),
                  ),
                  gridText(context, AppStrings.dash),
                ],
            ],
            footer: [
              gridText(context, _MText.workToday, bold: true),
              gridMoney(context, _egp(data.workTotalUnits), bold: true),
            ],
          ),
        ),
        if (data.status != null && data.status!.isNotEmpty)
          SectionNote(
            '${_MText.status}: ${dayStatusLabel(data.status)}',
            key: const Key('masraweya-status'),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// A small gold icon button, like the rest of the section's actions.
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

/// Raw inputs for one masraweya day. Totals stay on the server response.
class _MasraweyaForm extends ConsumerStatefulWidget {
  const _MasraweyaForm({required this.day, this.addRow = false});

  final MasraweyaDayDto day;

  /// Opens with one more, empty row (the screen's + صف).
  final bool addRow;

  @override
  ConsumerState<_MasraweyaForm> createState() => _MasraweyaFormState();
}

class _MasraweyaFormState extends ConsumerState<_MasraweyaForm> {
  late final TextEditingController _previous;
  late final TextEditingController _purchases;
  late final List<_EntryFields> _rows;

  @override
  void initState() {
    super.initState();
    final previous = widget.day.previousValueUnits;
    final purchases = widget.day.purchasesUnits;
    _previous = TextEditingController(text: _digits(previous));
    _purchases = TextEditingController(text: _digits(purchases));
    _rows = [
      for (final entry in widget.day.entries)
        _EntryFields(
          value: entry.valueUnits,
          commission: entry.commissionUnits,
        ),
    ];
    if (widget.addRow) _rows.add(_EntryFields());
    _previous.addListener(_changed);
    _purchases.addListener(_changed);
    for (final row in _rows) {
      row.value.addListener(_changed);
      row.commission.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _previous.removeListener(_changed);
    _purchases.removeListener(_changed);
    _previous.dispose();
    _purchases.dispose();
    for (final row in _rows) {
      row.value.removeListener(_changed);
      row.commission.removeListener(_changed);
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!permissionsOf(ref).canWrite(SectionKey.masraweya)) {
      return const SizedBox.shrink();
    }
    final live = ref.watch(masraweyaProvider).asData?.value;
    final version = live?.version ?? widget.day.version;
    final previous = parseUnits(_previous.text);
    final purchases = parseUnits(_purchases.text);
    final entries = _parsedEntries();
    final ready = previous != null && purchases != null && entries != null;
    return Column(
      key: const Key('masraweya-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.currentDay,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(live?.businessDate ?? widget.day.businessDate),
        const Text(AppStrings.noPreview),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('masraweya-previous-field'),
          controller: _previous,
          label: AppStrings.previousValue,
        ),
        const SizedBox(height: AppSpacing.md),
        UnitsField(
          key: const Key('masraweya-purchases-field'),
          controller: _purchases,
          label: AppStrings.purchasesValue,
        ),
        for (var i = 0; i < _rows.length; i++) ...[
          const SizedBox(height: AppSpacing.md),
          UnitsField(
            key: Key('masraweya-entry-value-field-$i'),
            controller: _rows[i].value,
            label: AppStrings.amount,
          ),
          const SizedBox(height: AppSpacing.md),
          UnitsField(
            key: Key('masraweya-entry-commission-field-$i'),
            controller: _rows[i].commission,
            label: AppStrings.commissions,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('masraweya-form-add-row'),
            onPressed: () => setState(() {
              final row = _EntryFields();
              row.value.addListener(_changed);
              row.commission.addListener(_changed);
              _rows.add(row);
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text(_MText.addRow),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GuardedMutation(
          buttonKey: const Key('save-masraweya'),
          inputs: _inputs(),
          expectedVersion: version,
          label: AppStrings.save,
          confirmText: ready ? AppStrings.saveDayConfirm : null,
          normalizedValue: ready
              ? _preview(previous, purchases, entries)
              : null,
          onVersionConflict: () => ref.invalidate(masraweyaProvider),
          onSubmit: (meta) => _submit(
            meta,
            previous: previous,
            purchases: purchases,
            entries: entries,
            businessDate: live?.businessDate ?? widget.day.businessDate,
          ),
        ),
      ],
    );
  }

  String _inputs() {
    final rows = _rows
        .map((row) => '${row.value.text},${row.commission.text}')
        .join(';');
    return '${_previous.text}|${_purchases.text}|$rows';
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

  String _preview(
    int previous,
    int purchases,
    List<MasraweyaEntryDto> entries,
  ) {
    final parts = <String>['$previous', '$purchases'];
    for (final entry in entries) {
      parts.add('${entry.valueUnits?.asInt ?? ''}');
      parts.add('${entry.commissionUnits?.asInt ?? ''}');
    }
    return parts.join(' · ');
  }

  Future<String?> _submit(
    MutationMeta meta, {
    required int? previous,
    required int? purchases,
    required List<MasraweyaEntryDto>? entries,
    required String businessDate,
  }) async {
    if (previous == null || purchases == null || entries == null) {
      return AppStrings.integerOnly;
    }
    final saved = await ref
        .read(masraweyaActionsProvider)
        .saveDay(
          SaveMasraweyaDayRequest(
            businessDate: businessDate,
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
