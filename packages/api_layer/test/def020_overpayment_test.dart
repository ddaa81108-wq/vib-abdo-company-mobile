import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// DEF-031. The contract accepts a partial payment above the stored balance
/// and returns the stored balance, which may be negative. There is no
/// `OVERPAYMENT` status. Success uses the same response as any other partial
/// payment (openapi documents HTTP 201; this fake's success envelope is 200).
void main() {
  test(
    'a direct partial payment above the stored balance is accepted',
    () async {
      final api = await _admin();
      final date = DateTime.utc(2026, 10, 22);

      final paid = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.partialPayment(inputValue: 400, date: date),
        MutationMeta(expectedVersion: 4, requestId: 'over-400'),
      );

      expect(paid.id, 'tx_new');
      expect(paid.version, 5);
      expect(paid.balanceUnits?.units, -80);
      expect(paid.balanceUnits!.isInvalid, isFalse);
      expect(paid.balanceUnits, isNot(0));
      expect(paid.raw['customerVersion'], 5);
      expect(paid.raw['balanceUnits'], -80);
      final transaction = paid.raw['transaction'] as Map;
      expect(transaction['id'], 'tx_new');
      expect(transaction['type'], 'payment');
      expect(transaction['paymentMode'], 'partial');
      expect(transaction['amountUnits'], 400);
      expect(transaction['inputValue'], 400);
      expect(transaction['currency'], 'LYD');
      expect(transaction['status'], 'posted');

      final after = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(after.balanceUnits?.units, -80);
      expect(after.version, 5);
      final ledger = await api.accounts.ledger(
        AccountSection.customers,
        'c_55',
      );
      final line = ledger.page.items.singleWhere(
        (entry) => entry.id.startsWith('tx_partial'),
      );
      expect(line.balanceAfterUnits?.units, -80);
      expect(line.amountUnits?.units, 400);
    },
  );

  test('an Egyptian deposit overpay is stored as a credit balance', () async {
    final api = await _admin();
    // `c_eg_08` stores 300 EGP. 400 is above that card.
    final paid = await api.accounts.addTransaction(
      AccountSection.egyptianDeposits,
      'c_eg_08',
      AccountTransactionRequest.partialPayment(
        inputValue: 400,
        date: DateTime.utc(2026, 10, 22),
      ),
      MutationMeta(expectedVersion: 4, requestId: 'egp-over-400'),
    );

    expect(paid.balanceUnits?.units, -100);
    expect((paid.raw['transaction'] as Map)['currency'], 'EGP');
    final card = await api.accounts.get(
      AccountSection.egyptianDeposits,
      'c_eg_08',
    );
    expect(card.balanceUnits?.units, -100);
    expect(card.currency, Currency.egp);
  });

  test('a payment equal to the stored balance returns balance 0', () async {
    final api = await _admin();
    final paid = await api.accounts.addTransaction(
      AccountSection.customers,
      'c_55',
      AccountTransactionRequest.partialPayment(
        inputValue: 320,
        date: DateTime.utc(2026, 10, 22),
      ),
      MutationMeta(expectedVersion: 4, requestId: 'exact-320'),
    );

    expect(paid.version, 5);
    expect(paid.balanceUnits?.units, 0);
    expect(paid.balanceUnits!.isInvalid, isFalse);
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
    // The factor is not an amount. The stored balance is unchanged and is
    // what the ack returns.
    expect(ack.balanceUnits?.units, 320);
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
