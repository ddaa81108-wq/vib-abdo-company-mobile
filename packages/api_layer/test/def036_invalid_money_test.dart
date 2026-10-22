/// DEF-036. One bad money field must not fail the response or become a number.
///
/// The skipped DEF-036 test on PR #60 lives in a file that branch adds
/// (`test/acceptance/phase8/phase8_reconciliation_test.dart`). These tests are
/// the equivalent here, so the two branches do not edit the same file.
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';
import 'package:flutter_api_layer/data/repositories/purchases_repository.dart';
import 'package:flutter_api_layer/data/repositories/treasury_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// One non-integer money token. [json] is spliced raw into a JSON object.
class _Kind {
  const _Kind(this.name, this.json, this.secret);
  final String name;
  final String json;
  final List<String> secret;
}

const _kinds = <_Kind>[
  _Kind('fraction', '10.005', ['10.005', '10 د.ل', '11 د.ل']),
  _Kind('string', '"1500"', ['1500', '1,500']),
  _Kind('huge', '123456789012345678901234', ['123456789012345678901234']),
];

const _names = ['اسم سري', 'عميل سليم', 'عميل صفر', 'صنف سري', 'صنف سليم'];

const _money = MoneyFormatter();

void main() {
  group('parser', () {
    test('a JSON integer stays exact and null stays null', () {
      expect(unitsOrNull(0)?.units, 0);
      expect(unitsOrNull(0)!.isInvalid, isFalse);
      expect(unitsOrNull(320)?.units, 320);
      expect(unitsOrNull(null), isNull);
      expect(_money.formatOrDash(null, Currency.lyd), '—');
      expect(_money.formatOrDash(unitsOrNull(0), Currency.lyd), '0 د.ل');
    });

    test('a double is never stored or rounded', () {
      final lines = _beginLog();
      final value = unitsOrNull(10.005, fieldPath: 'balanceUnits', rowId: 'c_frac');
      expect(value is double, isFalse);
      expect(value, isA<MoneyValue>());
      expect(value!.isInvalid, isTrue);
      expect(value.units, isNull);
      expect(value.asInt, isNull);
      expect(value, isNot(10));
      expect(value, isNot(0));
      expect(value.toString(), 'MoneyInvalid');
      expect(_money.formatOrDash(10.005, Currency.lyd), MoneyValue.invalidLabel);
      expect(_money.formatOrDash(value, Currency.lyd), MoneyValue.invalidLabel);
      _expectLine(lines, endpoint: '-', field: 'balanceUnits', row: 'c_frac');
      _expectClean(lines, const ['10.005', '10', 'اسم سري']);
    });

    test('list rows and summary totals keep every other field', () {
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        final page = runWithMoneyEndpoint(
          '/api/customers',
          () => AccountsPage.fromData(
            PreciseJson.decode(_customersJson(kind)),
            AccountSection.customers,
          ),
        );
        _expectCustomers(page, kind);
        _expectLine(lines, endpoint: '/api/customers', field: 'balanceUnits', row: 'c_frac');
        _expectLine(lines, endpoint: '/api/customers', field: 'balanceUnits', row: 'c_text');
        _expectLine(lines, endpoint: '/api/customers', field: 'balanceUnits', row: 'c_huge');
        _expectLine(lines, endpoint: '/api/customers', field: 'summary.netBalance', row: '-');
        expect(lines.any((line) => line.contains('row=c_ok')), isFalse, reason: kind.name);
        _expectClean(lines, [...kind.secret, ..._names]);
        _expectLogShape(lines);
      }
    });

    test('a single balance keeps the card', () {
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        final card = runWithMoneyEndpoint(
          '/api/customers/c_55',
          () => AccountCardDto.fromJson(
            PreciseJson.decode(_cardJson(kind)) as Map<String, dynamic>,
            AccountSection.customers,
          ),
        );
        expect(card.id, 'c_55', reason: kind.name);
        expect(card.name, 'اسم سري', reason: kind.name);
        expect(card.version, 4, reason: kind.name);
        _expectInvalid(card.balanceUnits, kind);
        _expectLine(lines, endpoint: '/api/customers/c_55', field: 'balanceUnits', row: 'c_55');
        _expectClean(lines, [...kind.secret, ..._names]);
      }
    });

    test('treasury totals keep the other totals', () {
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        final summary = runWithMoneyEndpoint(
          '/api/treasury',
          () => TreasurySummaryDto.fromData(PreciseJson.decode(_treasuryJson(kind))),
        );
        _expectInvalid(summary.receivablesUnits, kind);
        expect(summary.liabilitiesUnits?.units, 12000, reason: kind.name);
        expect(summary.netUnits?.units, 51000, reason: kind.name);
        expect(summary.egyptianSourceUnits?.units, 95000, reason: kind.name);
        expect(_money.formatOrDash(summary.netUnits, Currency.lyd), '51,000 د.ل');
        _expectLine(lines, endpoint: '/api/treasury', field: 'totals.receivablesUnits', row: '-');
        expect(lines.any((line) => line.contains('field=totals.netUnits')), isFalse);
        _expectClean(lines, [...kind.secret, ..._names]);
      }
    });

    test('purchases totals keep the day and the other lifetime fields', () {
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        final page = runWithMoneyEndpoint(
          '/api/purchases/al_bayan',
          () => PurchasesBookPage.fromData(PreciseJson.decode(_purchasesJson(kind))),
        );
        _expectPurchases(page, kind);
        _expectLine(
          lines,
          endpoint: '/api/purchases/al_bayan',
          field: 'lifetimeTotals.remainingUnits',
          row: '-',
        );
        _expectLine(lines, endpoint: '/api/purchases/al_bayan', field: 'resultUnits', row: 'e_bad');
        expect(lines.any((line) => line.contains('row=e_ok')), isFalse, reason: kind.name);
        _expectClean(lines, [...kind.secret, ..._names, '47447', '47,447']);
      }
    });

    test('a container that is not an object still fails the whole response', () {
      expect(
        () => AccountsPage.fromData(
          PreciseJson.decode('{"items":[{"id":"c_ok","balanceUnits":320}],"summary":[10635]}'),
          AccountSection.customers,
        ),
        throwsA(isA<InvalidServerResponseException>()),
      );
      expect(
        () => AccountsPage.fromData(PreciseJson.decode('"broken"'), AccountSection.customers),
        throwsA(isA<InvalidServerResponseException>()),
      );
      expect(
        () => TreasurySummaryDto.fromData(PreciseJson.decode('{"totals":"51000"}')),
        throwsA(isA<InvalidServerResponseException>()),
      );
      expect(
        () => PurchasesBookPage.fromData(
          PreciseJson.decode('{"days":[],"lifetimeTotals":[50000]}'),
        ),
        throwsA(isA<InvalidServerResponseException>()),
      );
    });

    test('encoding an invalid amount refuses instead of writing 0', () {
      expect(wireMoney(null), isNull);
      expect(wireMoney(const MoneyValue.known(0)), 0);
      expect(wireMoney(const MoneyValue.known(320)), 320);
      expect(
        () => wireMoney(const MoneyValue.invalid()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'refusing to encode an invalid amount',
          ),
        ),
      );
      const item = EmployeeTotalsItemDto(
        employeeName: 'اسم سري',
        employeeId: 'e1',
        collectedUnits: MoneyValue.invalid(),
        pendingUnits: MoneyValue.known(4),
      );
      expect(item.pendingUnits?.units, 4);
      StateError? refused;
      try {
        item.toJson();
      } on StateError catch (error) {
        refused = error;
      }
      expect(refused, isNotNull);
      expect(refused!.message, 'refusing to encode an invalid amount');
      expect(refused.toString().contains('10.005'), isFalse);
      expect(refused.toString().contains('اسم سري'), isFalse);
    });
  });

  group('repository', () {
    test('customers list marks the bad row and the bad summary', () async {
      final fake = await _admin();
      final repo = RemoteAccountsRepository(fake);
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        fake.scriptedGetJson['/api/customers'] = _customersJson(kind);
        final page = await repo.list(AccountSection.customers);
        _expectCustomers(page, kind);
        _expectLine(lines, endpoint: '/api/customers', field: 'balanceUnits', row: 'c_frac');
        _expectLine(lines, endpoint: '/api/customers', field: 'summary.netBalance', row: '-');
        _expectClean(lines, [...kind.secret, ..._names]);
        _expectLogShape(lines);
      }
    });

    test('customer card marks only that balance', () async {
      final fake = await _admin();
      final repo = RemoteAccountsRepository(fake);
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        fake.scriptedGetJson['/api/customers/c_55'] = _cardJson(kind);
        final card = await repo.get(AccountSection.customers, 'c_55');
        expect(card.name, 'اسم سري', reason: kind.name);
        expect(card.version, 4, reason: kind.name);
        _expectInvalid(card.balanceUnits, kind);
        _expectLine(lines, endpoint: '/api/customers/c_55', field: 'balanceUnits', row: 'c_55');
        _expectClean(lines, [...kind.secret, ..._names]);
      }
    });

    test('treasury summary marks the bad total only', () async {
      final fake = await _admin();
      final repo = RemoteTreasuryRepository(fake);
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        fake.scriptedGetJson['/api/treasury'] = _treasuryJson(kind);
        final summary = await repo.summary();
        _expectInvalid(summary.receivablesUnits, kind);
        expect(summary.netUnits?.units, 51000, reason: kind.name);
        expect(summary.liabilitiesUnits?.units, 12000, reason: kind.name);
        _expectLine(lines, endpoint: '/api/treasury', field: 'totals.receivablesUnits', row: '-');
        _expectClean(lines, [...kind.secret, ..._names]);
      }
    });

    test('purchases book marks the bad lifetime total and the bad row', () async {
      final fake = await _admin();
      final repo = RemotePurchasesRepository(fake);
      final lines = _beginLog();
      for (final kind in _kinds) {
        lines.clear();
        fake.scriptedGetJson['/api/purchases/al_bayan'] = _purchasesJson(kind);
        final page = await repo.list(PurchaseBook.alBayan);
        _expectPurchases(page, kind);
        _expectLine(
          lines,
          endpoint: '/api/purchases/al_bayan',
          field: 'lifetimeTotals.remainingUnits',
          row: '-',
        );
        _expectLine(lines, endpoint: '/api/purchases/al_bayan', field: 'resultUnits', row: 'e_bad');
        _expectClean(lines, [...kind.secret, ..._names]);
      }
    });

    test('the app gateway still does not round a fraction into an integer', () async {
      final api = ApiLayer.create(
        config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
        fakeLatency: Duration.zero,
      );
      addTearDown(api.dispose);
      await api.session.login(username: 'admin.demo', password: 'demo-only');
      final fake = api.client as FakeApiClient;
      final lines = _beginLog();
      fake.scriptedGetJson['/api/customers'] = _customersJson(_kinds.first);
      final page = await api.accounts.list(AccountSection.customers);
      _expectCustomers(page, _kinds.first);
      _expectLine(lines, endpoint: '/api/customers', field: 'balanceUnits', row: 'c_frac');
      _expectClean(lines, [..._kinds.first.secret, ..._names]);
    });
  });
}

void _expectCustomers(AccountsPage page, _Kind kind) {
  expect(page.page.items, hasLength(5), reason: kind.name);
  final byId = {for (final card in page.page.items) card.id: card};
  for (final id in ['c_frac', 'c_text', 'c_huge']) {
    _expectInvalid(byId[id]!.balanceUnits, kind, reason: id);
    expect(byId[id]!.name, 'اسم سري', reason: id);
  }
  expect(byId['c_ok']!.balanceUnits?.units, 320, reason: kind.name);
  expect(byId['c_ok']!.name, 'عميل سليم', reason: kind.name);
  expect(byId['c_zero']!.balanceUnits?.units, 0, reason: kind.name);
  expect(_money.formatOrDash(byId['c_zero']!.balanceUnits, Currency.lyd), '0 د.ل');
  expect(_money.formatOrDash(byId['c_ok']!.balanceUnits, Currency.lyd), '320 د.ل');
  _expectInvalid(page.summary.netBalanceUnits, kind, reason: 'summary');
  expect(page.summary.totalDebtUnits?.units, 10635, reason: kind.name);
  expect(_money.formatOrDash(page.summary.totalDebtUnits, Currency.lyd), '10,635 د.ل');
  expect(page.summary.activeCards, 5, reason: kind.name);
}

void _expectPurchases(PurchasesBookPage page, _Kind kind) {
  final totals = page.lifetimeTotals!;
  expect(totals.resultUnits?.units, 50000, reason: kind.name);
  expect(totals.paidUnits?.units, 47447, reason: kind.name);
  _expectInvalid(totals.remainingUnits, kind, reason: 'lifetime');
  expect(_money.formatOrDash(totals.resultUnits, Currency.lyd), '50,000 د.ل');
  final day = page.page.items.single;
  expect(day.todayResultUnits?.units, 100, reason: kind.name);
  expect(_money.formatOrDash(day.todayResultUnits, Currency.lyd), '100 د.ل');
  final bad = day.entries.singleWhere((entry) => entry.id == 'e_bad');
  final ok = day.entries.singleWhere((entry) => entry.id == 'e_ok');
  _expectInvalid(bad.resultUnits, kind, reason: 'e_bad');
  expect(bad.paidUnits?.units, 7, reason: kind.name);
  expect(bad.itemLabel, 'صنف سري', reason: kind.name);
  expect(ok.resultUnits?.units, 40, reason: kind.name);
  expect(ok.paidUnits?.units, 40, reason: kind.name);
  expect(_money.formatOrDash(ok.resultUnits, Currency.lyd), '40 د.ل');
  expect(_money.formatOrDash(bad.paidUnits, Currency.lyd), '7 د.ل');
}

void _expectInvalid(MoneyValue? value, _Kind kind, {String? reason}) {
  final where = reason ?? kind.name;
  expect(value, isNotNull, reason: where);
  expect(value!.isInvalid, isTrue, reason: where);
  expect(value.isValid, isFalse, reason: where);
  expect(value.units, isNull, reason: where);
  expect(value.asInt, isNull, reason: where);
  expect(value, const MoneyValue.invalid(), reason: where);
  expect(value.toString(), 'MoneyInvalid', reason: where);
  expect(value is double, isFalse, reason: where);
  expect(_money.formatOrDash(value, Currency.lyd), MoneyValue.invalidLabel, reason: where);
  for (final secret in kind.secret) {
    expect(value.toString().contains(secret), isFalse, reason: '$where $secret');
    expect(_money.formatOrDash(value, Currency.lyd).contains(secret), isFalse, reason: secret);
  }
}

List<String> _beginLog() {
  final lines = <String>[];
  SafeLog.sink = (message, {wrapWidth}) {
    if (message != null) lines.add(message);
  };
  addTearDown(() => SafeLog.sink = null);
  return lines;
}

void _expectLine(
  List<String> lines, {
  required String endpoint,
  required String field,
  required String row,
}) {
  expect(
    lines.any(
      (line) =>
          line.contains('endpoint=$endpoint') &&
          line.contains('field=$field') &&
          line.contains('row=$row'),
    ),
    isTrue,
    reason: lines.join('\n'),
  );
}

void _expectClean(List<String> lines, List<String> secrets) {
  final text = lines.join('\n');
  for (final secret in secrets) {
    expect(text.contains(secret), isFalse, reason: secret);
  }
}

void _expectLogShape(List<String> lines) {
  final shape = RegExp(r'^\[api\] invalid_money endpoint=\S+ field=\S+ row=\S+$');
  expect(lines, isNotEmpty);
  for (final line in lines) {
    expect(line, matches(shape), reason: line);
  }
}

Future<FakeApiClient> _admin() async {
  final api = FakeApiClient(latency: Duration.zero);
  await api.post(
    '/api/auth/login',
    body: {'username': 'admin.demo', 'password': 'demo-only'},
  );
  return api;
}

String _customersJson(_Kind kind) => '''
{
  "items": [
    {"id":"c_frac","name":"اسم سري","balanceUnits":10.005,"currency":"LYD"},
    {"id":"c_text","name":"اسم سري","balanceUnits":"1500","currency":"LYD"},
    {"id":"c_huge","name":"اسم سري","balanceUnits":123456789012345678901234,"currency":"LYD"},
    {"id":"c_ok","name":"عميل سليم","balanceUnits":320,"currency":"LYD"},
    {"id":"c_zero","name":"عميل صفر","balanceUnits":0,"currency":"LYD","zeroReview":{"status":"pending"}}
  ],
  "summary": {"netBalance":${kind.json},"totalDebt":10635,"activeCards":5},
  "totalItems": 5
}
''';

String _cardJson(_Kind kind) =>
    '{"id":"c_55","name":"اسم سري","balanceUnits":${kind.json},"currency":"LYD","version":4}';

String _treasuryJson(_Kind kind) => '''
{
  "version": 7,
  "totals": {
    "receivablesUnits": ${kind.json},
    "liabilitiesUnits": 12000,
    "activeCashUnits": 8000,
    "egyptianSourceUnits": 95000,
    "egyptianRate": "9.5",
    "egyptianConvertedUnits": 10000,
    "netUnits": 51000
  }
}
''';

String _purchasesJson(_Kind kind) => '''
{
  "days": [
    {
      "day": "1",
      "id": "day-1",
      "totals": {"todayResultUnits": 100, "todayPaidUnits": 40},
      "entries": [
        {"id":"e_ok","kind":"entry","itemLabel":"صنف سليم","resultUnits":40,"paidUnits":40,"remainingUnits":40},
        {"id":"e_bad","kind":"entry","itemLabel":"صنف سري","resultUnits":10.005,"paidUnits":7,"remainingUnits":7}
      ]
    }
  ],
  "lifetimeTotals": {
    "resultUnits": 50000,
    "paidUnits": 47447,
    "remainingUnits": ${kind.json}
  }
}
''';
