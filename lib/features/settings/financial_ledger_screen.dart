import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/export_pdf_button.dart';
import '../../ui/widgets/section_kit.dart';

class LedgerQuery {
  const LedgerQuery({this.section, this.currency, this.q = '', this.before});

  final FinancialLedgerSectionKey? section;
  final String? currency;
  final String q;

  /// Server `before` cursor. Null is the first page.
  final String? before;

  @override
  bool operator ==(Object other) =>
      other is LedgerQuery &&
      other.section == section &&
      other.currency == currency &&
      other.q == q &&
      other.before == before;

  @override
  int get hashCode => Object.hash(section, currency, q, before);
}

final ledgerPageProvider =
    FutureProvider.family<FinancialLedgerPage, LedgerQuery>((ref, query) async {
      watchSignedIn(ref);
      final layer = ref.read(apiLayerProvider);
      if (!layer.permissions.canViewFinancialLedger) {
        throw const ForbiddenException(code: 'FORBIDDEN', message: 'غير مصرح');
      }
      return layer.reports.financialLedger(
        before: query.before,
        sectionKey: query.section,
        currency: query.currency,
        q: query.q.isEmpty ? null : query.q,
      );
    });

class FinancialLedgerScreen extends ConsumerStatefulWidget {
  const FinancialLedgerScreen({super.key});

  static const screenKey = Key('screen-financial-ledger');

  @override
  ConsumerState<FinancialLedgerScreen> createState() =>
      _FinancialLedgerScreenState();
}

class _FinancialLedgerScreenState extends ConsumerState<FinancialLedgerScreen> {
  final _search = TextEditingController();
  FinancialLedgerSectionKey? _section;
  String? _currency;
  String? _before;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LedgerQuery get _query => LedgerQuery(
    section: _section,
    currency: _currency,
    q: _search.text.trim(),
    before: _before,
  );

  void _retarget({
    FinancialLedgerSectionKey? section,
    String? currency,
    bool clearSection = false,
    bool clearCurrency = false,
  }) {
    setState(() {
      if (clearSection) _section = null;
      if (section != null || clearSection) _section = section;
      if (clearCurrency) _currency = null;
      if (currency != null || clearCurrency) _currency = currency;
      _before = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!permissionsOf(ref).canViewFinancialLedger) {
      return const ForbiddenPane();
    }
    final page = ref.watch(ledgerPageProvider(_query));
    final money = ref.watch(apiLayerProvider).money;
    return SectionTheme(
      child: ListView(
        key: FinancialLedgerScreen.screenKey,
        padding: pagePadding(MediaQuery.sizeOf(context).width),
        children: [
          Text('سجل الأستاذ', style: cairo(22, 800)),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'قيود الصفحة كما أرسلها الخادم. إجمالي الصفحة ليس إجمالي المؤسسة.',
            key: Key('ledger-page-note'),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('تصفية الصفحة', style: cairo(14, 800)),
                  TextField(
                    key: const Key('ledger-search'),
                    controller: _search,
                    decoration: const InputDecoration(labelText: 'بحث'),
                    onSubmitted: (_) => setState(() => _before = null),
                  ),
                  DropdownButtonFormField<String?>(
                    key: const Key('ledger-currency'),
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'العملة'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(value: 'LYD', child: Text('دينار')),
                      DropdownMenuItem(value: 'EGP', child: Text('جنيه')),
                    ],
                    onChanged: (value) =>
                        _retarget(currency: value, clearCurrency: value == null),
                  ),
                  DropdownButtonFormField<FinancialLedgerSectionKey?>(
                    key: const Key('ledger-section'),
                    initialValue: _section,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'القسم'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('كل الأقسام'),
                      ),
                      for (final section in FinancialLedgerSectionKey.values)
                        if (section != FinancialLedgerSectionKey.unknown)
                          DropdownMenuItem(
                            value: section,
                            child: Text(_sectionLabel(section)),
                          ),
                    ],
                    onChanged: (value) => _retarget(
                      section: value,
                      clearSection: value == null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const ExportPdfButton(),
          page.when(
            loading: () => const SkeletonBox(height: 120),
            error: (error, _) => presentFailure(
              ref.read(errorHandlerProvider).toFailure(error),
              onRetry: () => ref.invalidate(ledgerPageProvider(_query)),
              retryKey: const Key('ledger-retry'),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppStrings.pageTotals, style: cairo(14, 800)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in data.pageTotals.entries)
                      _TotalFrame(
                        label: _currencyLabel(entry.key),
                        child: MoneyText(
                          _money(money, entry.key, entry.value),
                          key: Key('ledger-total-${entry.key}'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (data.page.items.isEmpty)
                  const EmptyPane(message: AppStrings.emptyLedger)
                else
                  for (final row in data.page.items) _LedgerRow(row: row),
                if (data.page.nextCursor != null)
                  Align(
                    alignment: AlignmentDirectional.center,
                    child: OutlinedButton(
                      key: const Key('ledger-older'),
                      onPressed: () => setState(
                        () => _before = data.page.nextCursor,
                      ),
                      child: const Text('أقدم'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _money(MoneyFormatter money, String code, MoneyValue units) {
    final currency = Currency.fromCode(code);
    if (units.isInvalid || units.units == null) return MoneyValue.invalidLabel;
    if (currency == null) return money.formatNumber(units.units!);
    return money.formatOrDash(units, currency);
  }
}

class _TotalFrame extends StatelessWidget {
  const _TotalFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: cairo(12, 700, color: gold)),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

String _currencyLabel(String code) => switch (code) {
  'LYD' => 'دينار',
  'EGP' => 'جنيه',
  _ => code,
};

class _LedgerRow extends ConsumerWidget {
  const _LedgerRow({required this.row});

  final FinancialLedgerEntryDto row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(apiLayerProvider).money;
    final amount = row.amountUnits;
    final text = amount == null || amount.isInvalid || amount.units == null
        ? MoneyValue.invalidLabel
        : money.formatOrDash(amount, row.currency);
    final scheme = Theme.of(context).colorScheme;
    final title = row.counterpartyName ?? row.description ?? row.id;
    final note = row.description != null && row.description != title
        ? row.description!
        : null;
    return Container(
      key: Key('ledger-entry-${row.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: cairo(15, 800)),
          if (note != null)
            Text(note, style: cairo(12, 600, color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          _Fact('القسم', _sectionText(row)),
          _Fact('الحالة', _statusText(row)),
          _Fact('المرجع', row.referenceNo ?? '—'),
          _Fact('المنفّذ', row.actorName ?? '—'),
          const SizedBox(height: AppSpacing.xs),
          Align(alignment: Alignment.centerLeft, child: MoneyText(text)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: cairo(12, 800))),
          Expanded(
            child: Text(value, style: cairo(12, 600, color: muted)),
          ),
        ],
      ),
    );
  }
}

String _sectionText(FinancialLedgerEntryDto row) {
  final key = row.sectionKey;
  if (key != null && key != FinancialLedgerSectionKey.unknown) {
    return _sectionLabel(key);
  }
  return row.sectionKeyRaw ?? row.section;
}

/// Names the contract `sourceStatus`. An unknown value stays as the server sent it.
String _statusText(FinancialLedgerEntryDto row) => switch (row.sourceStatus) {
  FinancialLedgerSourceStatus.draft => AppStrings.draft,
  FinancialLedgerSourceStatus.posted => 'مُثبت',
  _ => row.sourceStatusRaw ?? '—',
};

String _sectionLabel(FinancialLedgerSectionKey section) => switch (section) {
  FinancialLedgerSectionKey.customerDebts => 'ديون العملاء',
  FinancialLedgerSectionKey.companyDebts => 'ديون الشركات',
  FinancialLedgerSectionKey.libyanDeposits => 'أمانات ليبية',
  FinancialLedgerSectionKey.egyptianDeposits => 'أمانات مصرية',
  FinancialLedgerSectionKey.purchases => 'المشتريات',
  FinancialLedgerSectionKey.treasury => 'الخزينة',
  FinancialLedgerSectionKey.collections => 'الاستلامات',
  FinancialLedgerSectionKey.unknown => 'غير معروف',
};
