import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_providers.dart';
import 'session_providers.dart';

final accountQueryProvider = StateProvider.family<String, AccountSection>(
  (ref, section) => '',
);

final accountFilterProvider = StateProvider.family<String?, AccountSection>(
  (ref, section) => null,
);

/// Rows appended by «تحميل المزيد».
///
/// [build] watches the search text and the filter chip, so either change
/// drops the previous page. A load-more response for the old query must not
/// be appended after that (the screen checks the same values before [append]).
class AccountExtraCards extends Notifier<List<AccountCardDto>> {
  AccountExtraCards(this.section);

  final AccountSection section;

  @override
  List<AccountCardDto> build() {
    ref.watch(accountQueryProvider(section));
    ref.watch(accountFilterProvider(section));
    return const [];
  }

  void append(List<AccountCardDto> items) {
    if (items.isEmpty) return;
    state = [...state, ...items];
  }

  void clear() {
    state = const [];
  }
}

final accountExtraCardsProvider = NotifierProvider.autoDispose
    .family<AccountExtraCards, List<AccountCardDto>, AccountSection>(
      AccountExtraCards.new,
    );

/// `GET /api/{section}/suggestions?q` for the create-card name field.
/// An empty query does not call the server.
final accountNameSuggestionsProvider = FutureProvider.autoDispose
    .family<List<AccountSuggestionDto>, (AccountSection, String)>((
      ref,
      key,
    ) async {
      ref.watch(sessionStateProvider);
      final query = key.$2.trim();
      if (query.isEmpty) return const [];
      return ref.read(apiLayerProvider).accounts.suggestions(key.$1, query);
    });

final accountsProvider = FutureProvider.family<AccountsPage, AccountSection>((
  ref,
  section,
) async {
  ref.watch(sessionStateProvider);
  final query = ref.watch(accountQueryProvider(section)).trim();
  final filter = ref.watch(accountFilterProvider(section));
  return ref
      .read(apiLayerProvider)
      .accounts
      .list(section, q: query.isEmpty ? null : query, filter: filter);
});

final ledgerProvider =
    FutureProvider.family<LedgerPage, (AccountSection, String)>((
      ref,
      key,
    ) async {
      ref.watch(sessionStateProvider);
      return ref.read(apiLayerProvider).accounts.ledger(key.$1, key.$2);
    });

final accountCardProvider =
    FutureProvider.family<AccountCardDto, (AccountSection, String)>((
      ref,
      key,
    ) async {
      ref.watch(sessionStateProvider);
      return ref.read(apiLayerProvider).accounts.get(key.$1, key.$2);
    });

final exchangeRateProvider = FutureProvider<ExchangeRateDto>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).accounts.getExchangeRate();
});

final purchaseBookProvider = StateProvider<PurchaseBook>(
  (ref) => PurchaseBook.alBayan,
);

final purchasesProvider = FutureProvider<PurchasesBookPage>((ref) async {
  ref.watch(sessionStateProvider);
  final book = ref.watch(purchaseBookProvider);
  return ref.read(apiLayerProvider).purchases.list(book);
});

final collectionsProvider = FutureProvider<CollectionsOverviewDto>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).collections.overview();
});

final payrollProvider = FutureProvider<PayrollDto>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).collections.payroll();
});

final assigneesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).collections.assignees();
});

final treasuryProvider = FutureProvider<TreasurySummaryDto>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).treasury.summary();
});

final cashLedgerProvider = FutureProvider<Paged<CashEntryDto>>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).treasury.cashLedger();
});

final reportsProvider = FutureProvider<ReportsDto>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).reports.daily();
});

final financialLedgerProvider = FutureProvider<FinancialLedgerPage>((
  ref,
) async {
  ref.watch(sessionStateProvider);
  final layer = ref.read(apiLayerProvider);
  if (!layer.permissions.canViewFinancialLedger) {
    throw const ForbiddenException(code: 'FORBIDDEN', message: 'غير مصرح');
  }
  return layer.reports.financialLedger();
});

final notificationsProvider = FutureProvider<NotificationsPage>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).notifications.list();
});

final notificationPrefsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).notifications.preferences();
});

final masraweyaProvider = FutureProvider<MasraweyaDayDto>((ref) async {
  ref.watch(sessionStateProvider);
  return ref.read(apiLayerProvider).masraweya.getDay();
});
