import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DEF-020 a direct partial payment above the stored balance is refused',
      () async {
    final api = await _admin();
    final date = DateTime.utc(2026, 10, 22);

    await expectLater(
      api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.partialPayment(inputValue: 400, date: date),
        MutationMeta(expectedVersion: 4, requestId: 'over-400'),
      ),
      throwsA(
        isA<BadRequestException>()
            .having((error) => error.code, 'code', 'VALIDATION_ERROR')
            .having(
              (error) => error.message,
              'message',
              FakeApiClient.amountAboveRemainingMessage,
            ),
      ),
    );

    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(card.balanceUnits?.units, 320);
    expect(card.version, 4);
    final ledger = await api.accounts.ledger(AccountSection.customers, 'c_55');
    expect(
      ledger.page.items.where((entry) => entry.id.startsWith('tx_partial')),
      isEmpty,
    );

    // The same integer as the stored balance is still a payment. The server
    // stores the resulting balance. The app does not compute it.
    final paid = await api.accounts.addTransaction(
      AccountSection.customers,
      'c_55',
      AccountTransactionRequest.partialPayment(inputValue: 320, date: date),
      MutationMeta(expectedVersion: 4, requestId: 'exact-320'),
    );
    expect(paid.version, 5);
    final after = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(after.balanceUnits?.units, 0);
    expect(after.version, 5);
  });

  test('a divide payment is not compared with the stored balance', () async {
    final api = await _admin();
    final factor = DecimalString.tryParse('2');
    expect(factor, isNotNull);

    final ack = await api.accounts.addTransaction(
      AccountSection.customers,
      'c_55',
      AccountTransactionRequest.partialPayment(
        inputValue: 400,
        mode: CalculationMode.divide,
        factor: factor,
        date: DateTime.utc(2026, 10, 22),
      ),
      MutationMeta(expectedVersion: 4, requestId: 'divide-400'),
    );
    expect(ack.version, 5);
    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(card.balanceUnits?.units, 320);
    expect(card.version, 5);
  });
}

Future<ApiLayer> _admin() async {
  final api = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(api.dispose);
  await api.session.login(username: 'admin.demo', password: 'x');
  return api;
}
