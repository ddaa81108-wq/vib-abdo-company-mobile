import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/labeled_money.dart';
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
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle('صفحة المصراوية'),
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
    );
  }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(data.businessDate),
        const SizedBox(height: AppSpacing.md),
        _amount(
          'masraweya-previous',
          AppStrings.previousValue,
          data.previousValueUnits,
        ),
        _amount(
          'masraweya-purchases',
          AppStrings.purchasesValue,
          data.purchasesUnits,
        ),
        _amount(
          'masraweya-work-total',
          AppStrings.workTotal,
          data.workTotalUnits,
        ),
        _amount(
          'masraweya-remaining',
          AppStrings.remaining,
          data.remainingUnits,
        ),
        _amount(
          'masraweya-adjustment',
          AppStrings.adjustment,
          data.historicalAdjustmentUnits,
        ),
        for (var i = 0; i < data.entries.length; i++) ...[
          _amount(
            'masraweya-entry-$i',
            AppStrings.amount,
            data.entries[i].valueUnits,
          ),
          _amount(
            'masraweya-entry-commission-$i',
            AppStrings.commissions,
            data.entries[i].commissionUnits,
          ),
        ],
        Text(data.status ?? AppStrings.dash),
        if (canWrite) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GatedButton(
              buttonKey: const Key('edit-masraweya'),
              allowed: true,
              online: online,
              label: AppStrings.save,
              onPressed: () =>
                  showAppForm<void>(context, _MasraweyaForm(day: data)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _amount(String key, String label, int? units) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: LabeledMoney(
        key: Key(key),
        label: label,
        value: money.formatOrDash(units, Currency.egp),
      ),
    );
  }
}

class _EntryFields {
  _EntryFields({int? value, int? commission})
    : value = TextEditingController(text: value == null ? '' : '$value'),
      commission = TextEditingController(
        text: commission == null ? '' : '$commission',
      );

  final TextEditingController value;
  final TextEditingController commission;

  void dispose() {
    value.dispose();
    commission.dispose();
  }
}

/// Raw inputs for one masraweya day. Totals stay on the server response.
class _MasraweyaForm extends ConsumerStatefulWidget {
  const _MasraweyaForm({required this.day});

  final MasraweyaDayDto day;

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
    _previous = TextEditingController(
      text: previous == null ? '' : '$previous',
    );
    _purchases = TextEditingController(
      text: purchases == null ? '' : '$purchases',
    );
    _rows = [
      for (final entry in widget.day.entries)
        _EntryFields(
          value: entry.valueUnits,
          commission: entry.commissionUnits,
        ),
    ];
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
        MasraweyaEntryDto(valueUnits: value, commissionUnits: commission),
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
      parts.add('${entry.valueUnits}');
      parts.add('${entry.commissionUnits}');
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
