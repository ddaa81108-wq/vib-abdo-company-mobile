import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_providers.dart';
import 'pending_mutation.dart';
import 'router_provider.dart';
import 'section_providers.dart';
import 'session_providers.dart';

String? _userId(SessionState? session) => switch (session) {
  SessionAuthenticated(:final profile) => profile.id,
  _ => null,
};

/// Drops cached reads and user-scoped filters. Theme and connectivity stay.
void invalidateUserScope(WidgetRef ref) {
  ref.invalidate(homeDashboardProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(accountExtraCardsProvider);
  ref.invalidate(accountQueryProvider);
  ref.invalidate(accountFilterProvider);
  ref.invalidate(accountNameSuggestionsProvider);
  ref.invalidate(ledgerProvider);
  ref.invalidate(accountCardProvider);
  ref.invalidate(exchangeRateProvider);
  ref.invalidate(purchaseBookProvider);
  ref.invalidate(purchasesProvider);
  ref.invalidate(collectionsProvider);
  ref.invalidate(payrollProvider);
  ref.invalidate(assigneesProvider);
  ref.invalidate(treasuryProvider);
  ref.invalidate(cashLedgerProvider);
  ref.invalidate(reportsProvider);
  ref.invalidate(financialLedgerProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(notificationPrefsProvider);
  ref.invalidate(unreadCountProvider);
  ref.invalidate(masraweyaProvider);
}

/// Follows [sessionStateProvider]. Expiry and logout both come through that
/// state; this does not listen to a second auth stream.
void onSessionTransition(
  WidgetRef ref,
  SessionState? previous,
  SessionState next,
) {
  final previousId = _userId(previous);
  final nextId = _userId(next);
  if (next is SessionAuthenticated && previousId != nextId) {
    ref.read(pendingMutationProvider.notifier).discardUnless(nextId);
    invalidateUserScope(ref);
  }
  if (next is! SessionUnauthenticated || previous is! SessionAuthenticated) {
    return;
  }
  invalidateUserScope(ref);
  final router = ref.read(routerProvider);
  final path = router.state.uri.path;
  if (path != '/login' && path != '/signup-info') {
    router.go('/login');
  }
}
