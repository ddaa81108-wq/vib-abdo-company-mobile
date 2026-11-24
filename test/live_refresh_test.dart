import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/live_refresh.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';

void main() {
  test('a customer change reloads that list and not purchases', () {
    final providers = providersForSignal(
      const RealtimeSignalView(topic: 'customer.changed'),
    );
    expect(providers, contains(accountsProvider(AccountSection.customers)));
    expect(providers, contains(collectionsProvider));
    expect(providers, contains(homeDashboardProvider));
    expect(providers, isNot(contains(purchasesProvider)));
    expect(providers, isNot(contains(masraweyaProvider)));
  });

  test('purchases, masraweya, and treasury topics stay on their sections', () {
    final purchases = providersForSignal(
      const RealtimeSignalView(topic: 'purchases.changed'),
    );
    expect(purchases, contains(purchasesProvider));
    expect(purchases, contains(reportsProvider));
    expect(purchases, isNot(contains(masraweyaProvider)));

    final masraweya = providersForSignal(
      const RealtimeSignalView(topic: 'masraweya.changed'),
    );
    expect(masraweya, contains(masraweyaProvider));
    expect(masraweya, isNot(contains(purchasesProvider)));

    final treasury = providersForSignal(
      const RealtimeSignalView(topic: 'treasury.report.closed'),
    );
    expect(treasury, contains(treasuryProvider));
    expect(treasury, contains(cashLedgerProvider));
  });

  test('a full resync drops every section cache', () {
    final providers = providersForSignal(
      const RealtimeSignalView(topic: 'full_resync_required', fullResync: true),
    );
    expect(providers, contains(accountsProvider(AccountSection.companies)));
    expect(
      providers,
      contains(accountsProvider(AccountSection.egyptianDeposits)),
    );
    expect(providers, contains(purchasesProvider));
    expect(providers, contains(masraweyaProvider));
    expect(providers, contains(notificationsProvider));
  });

  test('opening a section again names that section cache', () {
    expect(
      providersForLocation('/companies/co_1'),
      contains(accountsProvider(AccountSection.companies)),
    );
    expect(providersForLocation('/purchases'), [purchasesProvider]);
    expect(providersForLocation('/masraweya'), [masraweyaProvider]);
    expect(
      providersForLocation('/notifications'),
      contains(notificationsProvider),
    );
    expect(providersForLocation('/settings/ledger'), isNotEmpty);
    expect(providersForLocation('/search'), isEmpty);
  });
}
