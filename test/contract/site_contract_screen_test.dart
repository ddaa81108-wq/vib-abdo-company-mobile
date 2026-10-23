/// Screen text for the site samples. Transport is [FakeApiClient] scripted GET.
/// The widgets and providers are the real ones.
@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/phase7_nav.dart';
import '../support/pump_app.dart';

void main() {
  final samples = PreciseJson.decode(
    File('packages/api_layer/test/contract/fixtures/site-api-samples.json')
        .readAsStringSync(),
  ) as Map;

  testWidgets('the customers screen shows the sample integers in LYD', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    fake.scriptedGetJson['/api/customers'] = jsonEncode(_data(samples, 'GET /api/customers'));
    await go(tester, '/customers');
    expect(find.text('1,550 د.ل'), findsWidgets);
    expect(find.text('عميل تحصيل الاختبار'), findsWidgets);
    expect(find.text('300 د.ل'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the treasury screen shows the sample LYD net and EGP source', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    fake.scriptedGetJson['/api/treasury'] = jsonEncode(_data(samples, 'GET /api/treasury'));
    await go(tester, '/treasury');
    expect(find.text('5,160 د.ل'), findsWidgets);
    expect(find.text('14,900 ج.م'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the customers strip titles total debt, not the net, for this section',
    (tester) async {
      markTestSkipped(
        'G-11. The summary strip uses صافي إجمالي الديون (netBalance) as '
        'the primary title for every section. The contract uses totalDebt '
        'for customers and companies.',
      );
    },
  );

  testWidgets(
    'a payment above the stored balance is sent after a warning',
    (tester) async {
      markTestSkipped(
        'G-13. The ledger dialog still refuses a partial payment above '
        'the cached balanceUnits. The contract accepts it and stores a '
        'negative balance (DEF-031).',
      );
    },
  );
}

Map<String, dynamic> _data(Map samples, String key) {
  final body = (samples[key] as Map)['body'] as Map;
  return (body['data'] as Map).cast<String, dynamic>();
}
