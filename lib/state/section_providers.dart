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

/// Rows appended by «تحميل المزيد» and «عرض الكل».
///
/// [build] watches the search text and the filter chip, so either change
/// drops the previous page and its cursor. A page fetched for the old query
/// must not be appended after that.
class AccountExtraCards extends Notifier<List<AccountCardDto>> {
  AccountExtraCards(this.section);

  final AccountSection section;
  String? _cursor;
  var _started = false;

  /// The last append crossed the retain cap and the next append should
  /// bring those dropped rows back instead of skipping them.
  var _replay = false;

  /// The user already asked for a page past the cap, so later appends stay
  /// contiguous from the newest card.
  var _extend = false;

  @override
  List<AccountCardDto> build() {
    ref.watch(accountQueryProvider(section));
    ref.watch(accountFilterProvider(section));
    _cursor = null;
    _started = false;
    _replay = false;
    _extend = false;
    return const [];
  }

  /// Cursor for the next page. Until the first [append], that is the first
  /// page's `nextCursor`. Afterwards it is the cursor the last page reported.
  String? cursorAfter(String? firstPageCursor) =>
      _started ? _cursor : firstPageCursor;

  void append(
    List<AccountCardDto> items, {
    String? nextCursor,
    int? retainLimit,
  }) {
    _started = true;
    if (items.isEmpty) {
      _cursor = nextCursor;
      _replay = false;
      return;
    }
    final known = {for (final card in state) card.id};
    final fresh = <AccountCardDto>[
      for (final card in items)
        if (known.add(card.id)) card,
    ];
    if (fresh.isEmpty) {
      _cursor = nextCursor;
      if (_replay) {
        _replay = false;
        _extend = true;
      }
      return;
    }
    if (retainLimit == null || _extend) {
      state = [...state, ...fresh];
      _cursor = nextCursor;
      return;
    }
    if (_replay) {
      state = [...state, ...fresh];
      _cursor = nextCursor;
      _replay = false;
      _extend = true;
      return;
    }
    final merged = [...state, ...fresh];
    if (merged.length <= retainLimit) {
      state = merged;
      _cursor = nextCursor;
      return;
    }
    // Keep the prefix next to the first page. Dropping the tail used to
    // leave the first page and the oldest cards on screen with a hole
    // between them (DEF-027).
    state = merged.sublist(0, retainLimit);
    final dropped = merged.length - retainLimit;
    final entirePageDropped = dropped >= fresh.length;
    if (entirePageDropped || _cursor != null) {
      _replay = true;
      return;
    }
    _cursor = nextCursor;
  }

  void clear() {
    _cursor = null;
    _started = false;
    _replay = false;
    _extend = false;
    state = const [];
  }

  /// Follows `nextCursor` until the server stops, using whatever [fetch]
  /// the caller builds from the current filter and search. [stillCurrent]
  /// must be false once that filter or search changes. A cursor that repeats
  /// the one just requested stops the walk.
  Future<void> loadRemaining({
    required String? firstPageCursor,
    required Future<AccountsPage> Function(String cursor) fetch,
    required bool Function() stillCurrent,
    int? retainLimit,
  }) async {
    var cursor = cursorAfter(firstPageCursor);
    while (cursor != null && cursor.isNotEmpty) {
      final requested = cursor;
      final page = await fetch(requested);
      if (!ref.mounted || !stillCurrent()) return;
      append(
        page.page.items,
        nextCursor: page.page.nextCursor,
        retainLimit: retainLimit,
      );
      final stored = _cursor;
      if (stored == null || stored.isEmpty || stored == requested) return;
      cursor = stored;
    }
  }
}

final accountExtraCardsProvider = NotifierProvider.autoDispose
    .family<AccountExtraCards, List<AccountCardDto>, AccountSection>(
      AccountExtraCards.new,
    );

/// User-scoped reads stop when the session is gone, so a 401 does not start
/// another request and the previous user's value is not fetched again.
void watchSignedIn(Ref ref) {
  final session = ref.watch(sessionStateProvider);
  if (session is! SessionAuthenticated) {
    throw const SessionExpiredException();
  }
}

/// `GET /api/{section}/suggestions?q` for the create-card name field.
/// An empty query does not call the server.
final accountNameSuggestionsProvider = FutureProvider.autoDispose
    .family<List<AccountSuggestionDto>, (AccountSection, String)>((
      ref,
      key,
    ) async {
      watchSignedIn(ref);
      final query = key.$2.trim();
      if (query.isEmpty) return const [];
      return ref.read(apiLayerProvider).accounts.suggestions(key.$1, query);
    });

final accountsProvider = FutureProvider.family<AccountsPage, AccountSection>((
  ref,
  section,
) async {
  watchSignedIn(ref);
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
      watchSignedIn(ref);
      return ref.read(apiLayerProvider).accounts.ledger(key.$1, key.$2);
    });

final accountCardProvider =
    FutureProvider.family<AccountCardDto, (AccountSection, String)>((
      ref,
      key,
    ) async {
      watchSignedIn(ref);
      return ref.read(apiLayerProvider).accounts.get(key.$1, key.$2);
    });

final exchangeRateProvider = FutureProvider<ExchangeRateDto>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).accounts.getExchangeRate();
});

final purchaseBookProvider = StateProvider<PurchaseBook>(
  (ref) => PurchaseBook.alBayan,
);

final purchasesProvider = FutureProvider<PurchasesPage>((ref) async {
  watchSignedIn(ref);
  final book = ref.watch(purchaseBookProvider);
  return ref.read(apiLayerProvider).purchases.list(book);
});

final collectionsProvider = FutureProvider<CollectionsOverviewDto>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).collections.overview();
});

final payrollProvider = FutureProvider<PayrollDto>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).collections.payroll();
});

final assigneesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).collections.assignees();
});

final treasuryProvider = FutureProvider<TreasurySummaryDto>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).treasury.summary();
});

final cashLedgerProvider = FutureProvider<Paged<CashEntryDto>>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).treasury.cashLedger();
});

final reportsProvider = FutureProvider<ReportsDto>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).reports.daily();
});

final financialLedgerProvider = FutureProvider<FinancialLedgerPage>((
  ref,
) async {
  watchSignedIn(ref);
  final layer = ref.read(apiLayerProvider);
  if (!layer.permissions.canViewFinancialLedger) {
    throw const ForbiddenException(code: 'FORBIDDEN', message: 'غير مصرح');
  }
  return layer.reports.financialLedger();
});

final notificationPrefsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).notifications.preferences();
});

final masraweyaProvider = FutureProvider<MasraweyaDayDto>((ref) async {
  watchSignedIn(ref);
  return ref.read(apiLayerProvider).masraweya.getDay();
});

/// Sends a masraweya day through the API layer's save method.
///
/// [MutationMeta] is the one the save form's guarded submit keeps: the same
/// request id while the inputs and expected version stay the same, and a new
/// id when either changes.
final masraweyaActionsProvider = Provider<MasraweyaActions>(
  (ref) => MasraweyaActions(ref.watch(apiLayerProvider)),
);

class MasraweyaActions {
  const MasraweyaActions(this._api);

  final ApiLayer _api;

  Future<MasraweyaDayDto> saveDay(
    SaveMasraweyaDayRequest request,
    MutationMeta meta,
  ) => _api.masraweya.saveDay(request, meta);
}
