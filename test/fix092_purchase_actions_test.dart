import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/core/network/api_endpoints.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// The captured `GET /api/purchases/al_bayan` body (`docs/api/evidence/api-samples.json`).
/// `mapEntry` stamps `dayStatus: "draft"` from `purchase_days.status`.
Map<String, Object?> _productionEntry(String id, int sequence) => {
  'id': id,
  'dayId': '9b294ca8-fc62-459e-ba56-5312e94681a9',
  'sequence': sequence,
  'dayNumber': 1,
  'businessDate': '2026-10-23',
  'dayStatus': 'draft',
  'dayClosingDebtUnits': 80,
  'itemCode': 'custom',
  'itemLabel': 'مشتريات اختبار',
  'egpValueUnits': 1000,
  'calculationMode': 'divide',
  'exchangeRate': 10,
  'resultUnits': 100,
  'paidUnits': 20,
  'remainingUnits': 80,
  'vodafoneConsumedUnits': 100,
  'actorName': 'مدير الاختبار',
  'actorIsOwner': true,
  'version': 1,
  'dayVersion': 2,
  'correctionOpen': false,
  'createdAt': '2026-10-22T22:33:25.399Z',
  'updatedAt': '2026-10-22T22:33:25.399Z',
};

Map<String, Object?> _productionPage(List<Map<String, Object?>> entries) => {
  'merchant': {'key': 'al_bayan', 'name': 'البيان'},
  'day': {
    'id': '9b294ca8-fc62-459e-ba56-5312e94681a9',
    'dayNumber': 1,
    'businessDate': '2026-10-23',
    'status': 'draft',
    'previousDebtUnits': 0,
    'previousVodafoneUnits': 5000,
    'todayResultUnits': 100,
    'todayPaidUnits': 20,
    'totalDebtUnits': 80,
    'vodafoneRemainingUnits': 4900,
    'version': 2,
    'correctionOpen': false,
  },
  'entries': [
    ...entries,
    {
      'id': 'posted-1',
      'dayId': 'posted-day',
      'sequence': 1,
      'dayNumber': 0,
      'businessDate': '2026-10-22',
      'dayStatus': 'finalized',
      'dayClosingDebtUnits': 0,
      'itemCode': 'fawry',
      'itemLabel': 'أمس',
      'egpValueUnits': 100,
      'calculationMode': 'divide',
      'exchangeRate': 10,
      'resultUnits': 10,
      'paidUnits': 10,
      'remainingUnits': 0,
      'vodafoneConsumedUnits': 0,
      'actorName': 'مدير الاختبار',
      'actorIsOwner': true,
      'version': 1,
      'dayVersion': 1,
      'correctionOpen': false,
    },
  ],
  'nextBefore': null,
  'registerTotals': {
    'resultUnits': 100,
    'paidUnits': 20,
    'remainingUnits': 80,
    'vodafoneConsumedUnits': 100,
    'vodafoneRemainingUnits': 4900,
  },
};

void main() {
  test('a row that omits dayStatus inherits the open day', () {
    final page = PurchasesPage.fromData({
      'day': {
        'id': '9b294ca8-fc62-459e-ba56-5312e94681a9',
        'status': 'draft',
        'version': 4,
        'dayNumber': 3,
        'correctionOpen': false,
      },
      'entries': [
        {
          'id': 'bare',
          'dayId': '9b294ca8-fc62-459e-ba56-5312e94681a9',
          'sequence': 1,
          'itemCode': 'fawry',
          'itemLabel': 'فوري',
          'egpValueUnits': 10,
          'paidUnits': 0,
          'resultUnits': 1,
          'version': 1,
        },
      ],
    });
    final row = page.entries.single;
    expect(row.dayStatus, 'draft');
    expect(row.dayVersion, 4);
  });

  testWidgets('production rows show pencil and X inside a 360dp screen', (
    tester,
  ) async {
    const size = Size(360, 1400);
    final layer = await pumpFakeApp(tester, size: size);
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    fake.scriptedGetJson[ApiEndpoints.purchases(
      PurchaseBook.alBayan.path,
    )] = jsonEncode(
      _productionPage([
        _productionEntry('row-1', 1),
        _productionEntry('row-2', 2),
        _productionEntry('row-3', 3),
      ]),
    );
    await go(tester, '/purchases');

    for (final id in ['row-1', 'row-2', 'row-3']) {
      final edit = tester.getRect(find.byKey(Key('edit-$id')));
      final delete = tester.getRect(find.byKey(Key('delete-$id')));
      expect(edit.left, greaterThanOrEqualTo(0), reason: id);
      expect(edit.right, lessThanOrEqualTo(size.width), reason: id);
      expect(delete.left, greaterThanOrEqualTo(0), reason: id);
      expect(delete.right, lessThanOrEqualTo(size.width), reason: id);
      expect(find.byKey(Key('purchase-saved-mark-$id')), findsNothing);
    }
    expect(find.byKey(const Key('edit-posted-1')), findsNothing);
    expect(
      find.byKey(const Key('purchase-saved-mark-posted-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
