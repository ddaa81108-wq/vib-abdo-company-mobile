import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// DEF-031 / DEF-036. `MutationAck.balanceUnits` is the integer the server
/// stored. One bad field does not fail the ack or become 0.
void main() {
  group('ack parsing', () {
    test('a present integer stays exact, including a credit balance', () {
      final ack = MutationAck.fromData(
        PreciseJson.decode(
          '{"id":"tx_new","version":5,"customerVersion":5,'
          '"balanceUnits":-80,"transaction":{"id":"tx_new"}}',
        ),
      );
      expect(ack.id, 'tx_new');
      expect(ack.version, 5);
      expect(ack.balanceUnits?.units, -80);
      expect(ack.balanceUnits!.isInvalid, isFalse);
      expect(ack.balanceUnits.toString(), 'MoneyValue');
    });

    test('customerVersion and transaction.id fill a contract body', () {
      final ack = MutationAck.fromData(
        PreciseJson.decode(
          '{"transaction":{"id":"tx_srv"},"customerVersion":2,"balanceUnits":750}',
        ),
      );
      expect(ack.id, 'tx_srv');
      expect(ack.version, 2);
      expect(ack.balanceUnits?.units, 750);
    });

    test('an existing version wins over customerVersion', () {
      final ack = MutationAck.fromData(
        PreciseJson.decode(
          '{"id":"tx_new","version":5,"customerVersion":9,"balanceUnits":1}',
        ),
      );
      expect(ack.version, 5);
      expect(ack.balanceUnits?.units, 1);
    });

    test('an absent balance stays null and is not 0', () {
      final missing = MutationAck.fromData(
        PreciseJson.decode('{"id":"tx","version":2}'),
      );
      final explicitNull = MutationAck.fromData(
        PreciseJson.decode('{"id":"tx","version":2,"balanceUnits":null}'),
      );
      expect(missing.balanceUnits, isNull);
      expect(missing.id, 'tx');
      expect(missing.version, 2);
      expect(explicitNull.balanceUnits, isNull);
      expect(explicitNull.version, 2);
      expect(const MoneyFormatter().formatOrDash(null, Currency.lyd), '—');
    });

    test('a stored zero stays zero', () {
      final ack = MutationAck.fromData(
        PreciseJson.decode('{"id":"tx","version":3,"balanceUnits":0}'),
      );
      expect(ack.balanceUnits?.units, 0);
      expect(ack.balanceUnits!.isInvalid, isFalse);
      expect(ack.balanceUnits, isNotNull);
    });

    test('a present non-integer is invalid on that field only', () {
      final lines = _beginLog();
      const secrets = ['10.005', '1500', '123456789012345678901234', 'اسم'];
      const cases = <String, String>{
        'fraction': '10.005',
        'string': '"1500"',
        'huge': '123456789012345678901234',
        'bool': 'true',
      };
      for (final entry in cases.entries) {
        lines.clear();
        final ack = runWithMoneyEndpoint(
          '/api/customers/c_55/transactions',
          () => MutationAck.fromData(
            PreciseJson.decode(
              '{"id":"tx_bad","version":5,"customerVersion":9,'
              '"balanceUnits":${entry.value}}',
            ),
          ),
        );
        expect(ack.id, 'tx_bad', reason: entry.key);
        expect(ack.version, 5, reason: entry.key);
        expect(ack.balanceUnits, isNotNull, reason: entry.key);
        expect(ack.balanceUnits!.isInvalid, isTrue, reason: entry.key);
        expect(ack.balanceUnits!.units, isNull, reason: entry.key);
        expect(ack.balanceUnits!.asInt, isNull, reason: entry.key);
        expect(ack.balanceUnits, isNot(0), reason: entry.key);
        expect(ack.balanceUnits, isNot(10), reason: entry.key);
        expect(ack.balanceUnits.toString(), 'MoneyInvalid', reason: entry.key);
        expect(
          lines.single,
          '[api] invalid_money endpoint=/api/customers/c_55/transactions '
          'field=balanceUnits row=tx_bad',
          reason: entry.key,
        );
        for (final secret in secrets) {
          expect(lines.single.contains(secret), isFalse, reason: secret);
        }
      }
    });

    test('a double is not stored or rounded', () {
      final lines = _beginLog();
      final ack = MutationAck.fromData({
        'id': 'tx_dbl',
        'version': 4,
        'balanceUnits': 10.005,
      });
      expect(ack.balanceUnits is double, isFalse);
      expect(ack.balanceUnits!.isInvalid, isTrue);
      expect(ack.balanceUnits!.units, isNull);
      expect(ack.balanceUnits, isNot(10));
      expect(ack.balanceUnits, isNot(0));
      expect(ack.id, 'tx_dbl');
      expect(ack.version, 4);
      expect(lines.single.contains('10.005'), isFalse);
    });
  });

  test(
    'the repository marks one invalid balance and leaves the card',
    () async {
      final api = await _admin();
      final fake = api.client as FakeApiClient;
      fake.scriptedMutationJson['/api/customers/c_55/transactions'] =
          '{"id":"tx_bad","version":5,"balanceUnits":10.005}';
      final lines = _beginLog();

      final ack = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.partialPayment(
          inputValue: 400,
          date: DateTime.utc(2026, 10, 22),
        ),
        MutationMeta(expectedVersion: 4, requestId: 'scripted-bad'),
      );

      expect(ack.id, 'tx_bad');
      expect(ack.version, 5);
      expect(ack.balanceUnits!.isInvalid, isTrue);
      expect(ack.balanceUnits!.units, isNull);
      expect(ack.balanceUnits, isNot(0));
      expect(
        lines.single,
        '[api] invalid_money endpoint=/api/customers/c_55/transactions '
        'field=balanceUnits row=tx_bad',
      );
      expect(lines.single.contains('10.005'), isFalse);
      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits?.units, 320);
      expect(card.version, 4);
    },
  );

  test(
    'a collection overpay is accepted and returns the credit balance',
    () async {
      final api = await _admin();
      final submitted = await api.collections.submit(
        'as_1',
        mode: 'partial',
        amountUnits: 400,
        meta: MutationMeta(requestId: 'col-over-submit'),
      );
      expect(submitted.balanceUnits, isNull);
      expect(submitted.raw.containsKey('balanceUnits'), isFalse);
      final before = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(before.balanceUnits?.units, 320);

      final decided = await api.collections.decide(
        submitted.id!,
        CollectionDecision.approve,
        meta: MutationMeta(requestId: 'col-over-decide'),
      );
      expect(decided.version, isNull);
      expect(decided.raw['status'], 'approved');
      expect(decided.raw['transactionId'], 'collection-${submitted.id}');
      expect(decided.raw.containsKey('version'), isFalse);
      expect(decided.balanceUnits?.units, -80);
      expect(decided.balanceUnits, isNot(0));
      expect(decided.raw['balanceUnits'], -80);

      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits?.units, -80);
      expect(card.balanceUnits, decided.balanceUnits);
    },
  );

  test('rejecting a collection omits balanceUnits and does not post', () async {
    final api = await _admin();
    final submitted = await api.collections.submit(
      'as_1',
      mode: 'partial',
      amountUnits: 400,
      meta: MutationMeta(requestId: 'col-reject-submit'),
    );
    final decided = await api.collections.decide(
      submitted.id!,
      CollectionDecision.reject,
      meta: MutationMeta(requestId: 'col-reject-decide'),
    );
    expect(decided.balanceUnits, isNull);
    expect(decided.raw.containsKey('balanceUnits'), isFalse);
    expect(decided.raw.containsKey('transactionId'), isFalse);
    expect(decided.raw['status'], 'rejected');
    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(card.balanceUnits?.units, 320);
    expect(card.version, 4);
  });

  test(
    'an unlinked fixture approval without a customer keeps its amount',
    () async {
      final api = await _admin();
      final ack = await api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: MutationMeta(requestId: 'sb1-approve'),
      );
      // sb_1 is not linked to a card. The ack still carries the stored amount
      // and does not invent a customer balance or a zero.
      expect(ack.balanceUnits?.units, 100);
      expect(ack.raw['balanceUnits'], 100);
      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits?.units, 320);
    },
  );
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

List<String> _beginLog() {
  final lines = <String>[];
  SafeLog.sink = (message, {wrapWidth}) {
    if (message != null) lines.add(message);
  };
  addTearDown(() => SafeLog.sink = null);
  return lines;
}
