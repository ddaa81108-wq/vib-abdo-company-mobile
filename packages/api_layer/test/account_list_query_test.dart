import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list sends filter for Egyptian deposits the same way as customers',
      () async {
    final api = ApiLayer.create(
      config:
          const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: 'admin.demo', password: 'x');
    final fake = api.client as FakeApiClient;

    await api.accounts.list(AccountSection.egyptianDeposits, filter: 'pinned');
    await api.accounts.list(
      AccountSection.customers,
      filter: 'pendingReview',
      q: 'عميل',
    );
    await api.accounts.list(AccountSection.libyanDeposits);

    expect(
      fake.accountListQueries.map((query) => query.section),
      ['egyptian-deposits', 'customers', 'libyan-deposits'],
    );
    expect(fake.accountListQueries[0].filter, 'pinned');
    expect(fake.accountListQueries[1].filter, 'pendingReview');
    expect(fake.accountListQueries[1].q, 'عميل');
    expect(fake.accountListQueries[2].filter, isNull);
  });

  test('suggestions keep the section and the query', () async {
    final api = ApiLayer.create(
      config:
          const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: 'admin.demo', password: 'x');
    final fake = api.client as FakeApiClient;
    fake.suggestionItems = [
      {'id': 'c_9', 'name': 'قريب', 'phone': '091'},
    ];

    final items =
        await api.accounts.suggestions(AccountSection.companies, 'قر');

    expect(items.single.id, 'c_9');
    expect(items.single.name, 'قريب');
    expect(items.single.phone, '091');
    expect(fake.suggestionQueries.single.section, 'companies');
    expect(fake.suggestionQueries.single.q, 'قر');
  });
}
