/// P-04 / DEF-034. The purchases page is the contract shape in
/// docs/api/evidence/api-samples.json. `days`, `lifetimeTotals`, and `totals`
/// are not read.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/purchases_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> samples;

  setUpAll(() {
    final decoded = PreciseJson.decode(_samplesFile().readAsStringSync());
    expect(decoded, isA<Map>());
    samples = Map<String, dynamic>.from(decoded as Map);
  });

  test('the al_bayan and simsim samples parse', () {
    final alBayan = _data(samples, 'GET /api/purchases/al_bayan');
    final simsim = _data(samples, 'GET /api/purchases/simsim');
    for (final data in [alBayan, simsim]) {
      expect(data.containsKey('days'), isFalse);
      expect(data.containsKey('lifetimeTotals'), isFalse);
      expect(data.containsKey('totals'), isFalse);
    }
    _expectAlBayan(PurchasesPage.fromData(alBayan));
    _expectSimsim(PurchasesPage.fromData(simsim));
    expect(vodafoneCurrency, Currency.egp);
  });

  test(
    'the repository parses the al_bayan sample from the fake transport',
    () async {
      final api = FakeApiClient(latency: Duration.zero);
      await api.post(
        '/api/auth/login',
        body: {'username': 'admin.demo', 'password': 'demo-only'},
      );
      final data = _data(samples, 'GET /api/purchases/al_bayan');
      api.scriptedGetJson['/api/purchases/al_bayan'] = jsonEncode(data);
      final page = await RemotePurchasesRepository(api)
          .list(PurchaseBook.alBayan);
      _expectAlBayan(page);
    },
  );

  test('nextBefore is an integer cursor', () {
    final page = PurchasesPage.fromData({
      'entries': <Object>[],
      'nextBefore': 17,
    });
    expect(page.nextBefore, 17);
    expect(
      () => PurchasesPage.fromData({'entries': <Object>[], 'nextBefore': '17'}),
      throwsA(isA<InvalidServerResponseException>()),
    );
  });
}

void _expectAlBayan(PurchasesPage page) {
  expect(page.merchant?.key, 'al_bayan');
  expect(page.merchant?.name, 'البيان');
  final day = page.day!;
  expect(day.id, '9b294ca8-fc62-459e-ba56-5312e94681a9');
  expect(day.dayNumber, 1);
  expect(day.businessDate, '2026-10-23');
  expect(day.status, 'draft');
  expect(day.version, 2);
  expect(day.correctionOpen, isFalse);
  expect(day.previousDebtUnits?.asInt, 0);
  expect(day.previousVodafoneUnits?.asInt, 5000);
  expect(day.todayResultUnits?.asInt, 100);
  expect(day.todayPaidUnits?.asInt, 20);
  expect(day.totalDebtUnits?.asInt, 80);
  expect(day.vodafoneRemainingUnits?.asInt, 4900);
  expect(page.nextBefore, isNull);
  final totals = page.registerTotals!;
  expect(totals.resultUnits?.asInt, 100);
  expect(totals.paidUnits?.asInt, 20);
  expect(totals.remainingUnits?.asInt, 80);
  expect(totals.vodafoneConsumedUnits?.asInt, 100);
  expect(totals.vodafoneRemainingUnits?.asInt, 4900);
  final entry = page.entries.single;
  expect(entry.id, 'd0f6a687-1267-471b-831e-a4568602d82c');
  expect(entry.dayId, day.id);
  expect(entry.sequence, 1);
  expect(entry.dayNumber, 1);
  expect(entry.dayStatus, 'draft');
  expect(entry.dayClosingDebtUnits?.asInt, 80);
  expect(entry.version, 1);
  expect(entry.dayVersion, 2);
  expect(entry.correctionOpen, isFalse);
  expect(entry.itemCode, 'custom');
  expect(entry.calculationMode, CalculationMode.divide);
  expect(entry.exchangeRate?.value, '10');
  expect(entry.egpValueUnits?.asInt, 1000);
  expect(entry.resultUnits?.asInt, 100);
  expect(entry.paidUnits?.asInt, 20);
  expect(entry.remainingUnits?.asInt, 80);
  expect(entry.vodafoneConsumedUnits?.asInt, 100);
  expect(entry.actorIsOwner, isTrue);
}

void _expectSimsim(PurchasesPage page) {
  expect(page.merchant?.key, 'simsim');
  expect(page.merchant?.name, 'سمسم');
  expect(page.day!.dayNumber, 1);
  expect(page.day!.status, 'draft');
  expect(page.day!.version, 0);
  expect(page.day!.correctionOpen, isFalse);
  expect(page.day!.previousDebtUnits?.asInt, 0);
  expect(page.day!.vodafoneRemainingUnits?.asInt, 0);
  expect(page.entries, isEmpty);
  expect(page.nextBefore, isNull);
  expect(page.registerTotals?.resultUnits?.asInt, 0);
  expect(page.registerTotals?.paidUnits?.asInt, 0);
  expect(page.registerTotals?.remainingUnits?.asInt, 0);
  expect(page.registerTotals?.vodafoneConsumedUnits?.asInt, 0);
  expect(page.registerTotals?.vodafoneRemainingUnits?.asInt, 0);
}

Map<String, dynamic> _data(Map<String, dynamic> samples, String key) {
  final sample = samples[key];
  expect(sample, isA<Map>(), reason: key);
  final envelope = Map<String, dynamic>.from(sample as Map);
  expect(envelope['status'], 200, reason: key);
  final body = envelope['body'];
  expect(body, isA<Map>(), reason: key);
  final data = Map<String, dynamic>.from(body as Map)['data'];
  expect(data, isA<Map>(), reason: key);
  return Map<String, dynamic>.from(data as Map);
}

File _samplesFile() {
  for (final path in const [
    'docs/api/evidence/api-samples.json',
    '../../docs/api/evidence/api-samples.json',
  ]) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  fail('docs/api/evidence/api-samples.json was not found');
}
