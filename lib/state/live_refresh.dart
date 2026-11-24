import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../authentication/auth_gate.dart';
import '../features/settings/financial_ledger_screen.dart';
import 'notification_providers.dart';
import 'section_providers.dart';
import 'session_providers.dart';

/// Providers a realtime topic should drop so the next read comes from the server.
///
/// The website refreshes a section only for the topics that section listens to
/// (`useDebtRealtime`, `useCollectionsDashboard`, `usePurchasesPage`,
/// `useMasraweyaDay`, `TreasurySection`, `useReportOverview`). Payloads are
/// not applied. Unwatched providers do not call the network.
List<Object> providersForSignal(RealtimeSignalView signal) {
  if (signal.fullResync) return allLiveProviders();
  final out = <Object>[homeDashboardProvider, unreadCountProvider];
  final topic = signal.topic;
  void add(Object provider) {
    if (!out.contains(provider)) out.add(provider);
  }

  if (topic == 'customer.changed' || topic == 'customer.ledger.changed') {
    add(accountsProvider(AccountSection.customers));
    add(ledgerProvider);
    add(accountCardProvider);
  }
  if (topic == 'company.changed' || topic == 'company.ledger.changed') {
    add(accountsProvider(AccountSection.companies));
    add(ledgerProvider);
    add(accountCardProvider);
  }
  if (topic == 'libyan-deposit.changed' ||
      topic == 'libyan-deposit.ledger.changed') {
    add(accountsProvider(AccountSection.libyanDeposits));
    add(ledgerProvider);
    add(accountCardProvider);
  }
  if (topic == 'egyptian-deposit.changed' ||
      topic == 'egyptian-deposit.ledger.changed') {
    add(accountsProvider(AccountSection.egyptianDeposits));
    add(ledgerProvider);
    add(accountCardProvider);
    add(exchangeRateProvider);
  }
  if (topic == 'customer.changed' ||
      topic == 'customer.ledger.changed' ||
      topic == 'company.changed' ||
      topic == 'company.ledger.changed' ||
      topic == 'collection.changed') {
    add(collectionsProvider);
    add(payrollProvider);
    add(assigneesProvider);
  }
  if (topic == 'purchases.changed') add(purchasesProvider);
  if (topic == 'masraweya.changed') add(masraweyaProvider);
  const treasury = {
    'financial.summary.changed',
    'customer.changed',
    'company.changed',
    'libyan-deposit.changed',
    'egyptian-deposit.changed',
    'collection.changed',
    'treasury.changed',
    'customer.ledger.changed',
    'company.ledger.changed',
    'libyan-deposit.ledger.changed',
    'egyptian-deposit.ledger.changed',
    'purchases.changed',
    'masraweya.changed',
    'treasury.report.closed',
  };
  if (treasury.contains(topic)) {
    add(treasuryProvider);
    add(cashLedgerProvider);
  }
  const reports = {
    'financial.summary.changed',
    'customer.changed',
    'company.changed',
    'libyan-deposit.changed',
    'egyptian-deposit.changed',
    'collection.changed',
    'treasury.changed',
    'customer.ledger.changed',
    'company.ledger.changed',
    'libyan-deposit.ledger.changed',
    'egyptian-deposit.ledger.changed',
    'purchases.changed',
    'masraweya.changed',
    'treasury.report.closed',
  };
  if (reports.contains(topic)) {
    add(reportsProvider);
    add(financialLedgerProvider);
    add(ledgerPageProvider);
  }
  return out;
}

/// Every cached section read. Used on resume and on `full_resync_required`.
List<Object> allLiveProviders() => [
  homeDashboardProvider,
  unreadCountProvider,
  unreadNotificationsCountProvider,
  notificationsProvider,
  accountsProvider(AccountSection.customers),
  accountsProvider(AccountSection.companies),
  accountsProvider(AccountSection.libyanDeposits),
  accountsProvider(AccountSection.egyptianDeposits),
  ledgerProvider,
  accountCardProvider,
  exchangeRateProvider,
  collectionsProvider,
  payrollProvider,
  assigneesProvider,
  purchasesProvider,
  masraweyaProvider,
  treasuryProvider,
  cashLedgerProvider,
  reportsProvider,
  financialLedgerProvider,
  ledgerPageProvider,
];

void applyLiveSignal(WidgetRef ref, RealtimeSignalView signal) {
  for (final provider in providersForSignal(signal)) {
    ref.invalidate(provider as dynamic);
  }
}

void refreshAllLiveSections(WidgetRef ref) {
  for (final provider in allLiveProviders()) {
    ref.invalidate(provider as dynamic);
  }
}

/// Sections behind [path], including a card under that section.
List<Object> providersForLocation(String path) {
  final clean = path.split('?').first;
  if (clean == '/' || clean.isEmpty) {
    return [homeDashboardProvider, unreadCountProvider];
  }
  if (clean == '/notifications') {
    return [notificationsProvider, unreadCountProvider];
  }
  if (clean == '/settings/ledger') return [ledgerPageProvider];
  final section = sectionForLocation(clean);
  if (section == null) return const [];
  return switch (section) {
    SectionKey.customers => [
      accountsProvider(AccountSection.customers),
      ledgerProvider,
      accountCardProvider,
    ],
    SectionKey.companies => [
      accountsProvider(AccountSection.companies),
      ledgerProvider,
      accountCardProvider,
    ],
    SectionKey.libyanDeposits => [
      accountsProvider(AccountSection.libyanDeposits),
      ledgerProvider,
      accountCardProvider,
    ],
    SectionKey.egyptianDeposits => [
      accountsProvider(AccountSection.egyptianDeposits),
      ledgerProvider,
      accountCardProvider,
      exchangeRateProvider,
    ],
    SectionKey.collections => [
      collectionsProvider,
      payrollProvider,
      assigneesProvider,
    ],
    SectionKey.purchases => [purchasesProvider],
    SectionKey.masraweya => [masraweyaProvider],
    SectionKey.treasury => [treasuryProvider, cashLedgerProvider],
    SectionKey.reports => [reportsProvider],
  };
}

/// Refetch a section the user just opened when a previous response is cached.
///
/// The first visit has no value yet, so the screen's own watch is the only
/// request. A later visit drops the cache.
void refreshCachedLocation(WidgetRef ref, String path) {
  for (final provider in providersForLocation(path)) {
    _invalidateIfCached(ref, provider);
  }
}

void _invalidateIfCached(WidgetRef ref, Object provider) {
  try {
    final value = ref.read(provider as dynamic);
    if (value is AsyncValue && value.hasValue) {
      ref.invalidate(provider as dynamic);
    }
  } catch (_) {
    // A provider that is not ready stays as it is.
  }
}

/// Drops the cached page for the route the user just opened.
class SectionRouteRefresh extends ConsumerStatefulWidget {
  const SectionRouteRefresh({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SectionRouteRefresh> createState() =>
      _SectionRouteRefreshState();
}

class _SectionRouteRefreshState extends ConsumerState<SectionRouteRefresh> {
  String? _path;

  @override
  Widget build(BuildContext context) {
    final path = _routePath(context);
    if (path != null && path != _path) {
      final next = path;
      _path = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _path != next) return;
        refreshCachedLocation(ref, next);
      });
    }
    return widget.child;
  }
}

String? _routePath(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    return null;
  }
}

/// A topic plus the resync flag. Kept separate from the API type so tests
/// do not need a live socket.
class RealtimeSignalView {
  const RealtimeSignalView({required this.topic, this.fullResync = false});

  final String topic;
  final bool fullResync;
}
