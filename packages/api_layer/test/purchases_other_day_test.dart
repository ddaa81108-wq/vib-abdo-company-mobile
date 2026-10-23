// An entry from another day stays on the purchases page, and a write of the
// open day's entry sends that entry's dayVersion.
import 'dart:convert';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a write sends the entry dayVersion and keeps the other day', () async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: 'admin.demo', password: 'x');

    final page = await api.purchases.list(PurchaseBook.alBayan);
    final day = page.day!;
    final current = page.entries.singleWhere((entry) => entry.dayId == day.id);
    final other = page.entries.singleWhere((entry) => entry.dayId != day.id);
    expect(current.id, 'pe_1');
    expect(current.dayVersion, 3);
    expect(other.id, 'pe_old');
    expect(other.dayId, '11');
    expect(other.dayVersion, 1);
    expect(other.dayVersion, isNot(day.version));

    await api.purchases.delete(
      PurchaseBook.alBayan,
      current.id,
      MutationMeta(expectedVersion: current.dayVersion, requestId: 'del-pe-1'),
    );
    final fake = api.client as FakeApiClient;
    final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
    expect(body['expectedDayVersion'], current.dayVersion);
    expect(body['expectedDayVersion'], isNot(other.dayVersion));
    expect(fake.mutationPaths.last, '/api/purchases/al_bayan/entries/pe_1');

    final again = await api.purchases.list(PurchaseBook.alBayan);
    expect(again.entries.map((entry) => entry.id), contains('pe_old'));
    expect(
        again.entries.singleWhere((entry) => entry.id == 'pe_old').dayId, '11');
    expect(
      again.entries.singleWhere((entry) => entry.id == 'pe_old').dayVersion,
      1,
    );
  });
}
