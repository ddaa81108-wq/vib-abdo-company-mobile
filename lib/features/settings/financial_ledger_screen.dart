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
import '../../ui/widgets/section_kit.dart';

class LedgerQuery {
  const LedgerQuery({this.section, this.currency, this.q = ''});

  final FinancialLedgerSectionKey? section;
  final String? currency;
  final String q;

  @override
  bool operator ==(Object other) =>
      other is LedgerQuery &&
      other.section == section &&
      other.currency == currency &&
      other.q == q;

  @override
  int get hashCode => Object.hash(section, currency, q);
}

final ledgerPageProvider =
    FutureProvider.family<FinancialLedgerPage, LedgerQuery>((ref, query) async {
      watchSignedIn(ref);
      final layer = ref.read(apiLayerProvider);
      if (!layer.permissions.canViewFinancialLedger) {
        throw const ForbiddenException(code: 'FORBIDDEN', message: 'غير مصرح');
      }
      return layer.reports.financialLedger(
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LedgerQuery get _query => LedgerQuery(
    section: _section,
    currency: _currency,
    q: _search.text.trim(),
  );

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
          const Text(
            'قيود الصفحة كما أرسلها الخادم. إجمالي الصفحة ليس إجمالي المؤسسة.',
            key: Key('ledger-page-note'),
          ),
          TextField(
            key: const Key('ledger-search'),
            controller: _search,
            decoration: const InputDecoration(labelText: 'بحث'),
            onSubmitted: (_) => setState(() {}),
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
            onChanged: (value) => setState(() => _currency = value),
          ),
          DropdownButtonFormField<FinancialLedgerSectionKey?>(
            key: const Key('ledger-section'),
            initialValue: _section,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'القسم'),
            items: [
              const DropdownMenuItem(value: null, child: Text('كل الأقسام')),
              for (final section in FinancialLedgerSectionKey.values)
                if (section != FinancialLedgerSectionKey.unknown)
                  DropdownMenuItem(
                    value: section,
                    child: Text(_sectionLabel(section)),
                  ),
            ],
            onChanged: (value) => setState(() => _section = value),
          ),
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
                Text(AppStrings.pageTotals),
                for (final entry in data.pageTotals.entries)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MoneyText(
                      _money(money, entry.key, entry.value),
                      key: Key('ledger-screen-total-${entry.key}'),
                    ),
                  ),
                if (data.page.items.isEmpty)
                  const EmptyPane(message: AppStrings.emptyLedger)
                else
                  for (final row in data.page.items) _LedgerRow(row: row),
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
    final detail = [
      if (row.sectionKeyRaw != null) row.sectionKeyRaw,
      if (row.sourceStatusRaw != null) row.sourceStatusRaw,
      if (row.referenceNo != null) row.referenceNo,
      if (row.actorName != null) row.actorName,
    ].join(' · ');
    return Padding(
      key: Key('ledger-entry-${row.id}'),
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(row.counterpartyName ?? row.description ?? row.id),
          if (detail.isNotEmpty) Text(detail),
          Align(alignment: Alignment.centerLeft, child: MoneyText(text)),
        ],
      ),
    );
  }
}

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
