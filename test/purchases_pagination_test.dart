import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('purchases load the next page by the server before cursor', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    fake.purchaseFirstNextBefore = 11;
    fake.purchaseOlderPages[11] = {
      'entries': [_older('pe_1'), _older('pe_page2', resultUnits: 1)],
      'nextBefore': null,
    };
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchase-entry-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-entry-pe_page2')), findsNothing);
    expect(find.byKey(const Key('purchases-older')), findsOneWidget);
    expect(find.textContaining('50,000'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('purchases-older')));
    await tester.tap(find.byKey(const Key('purchases-older')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('purchase-entry-pe_page2')), findsOneWidget);
    expect(find.byKey(const Key('purchase-entry-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchases-older')), findsNothing);
    expect(find.textContaining('50,000'), findsWidgets);
    expect(find.textContaining('50,001'), findsNothing);
    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(
      fake.purchaseQueries.where((query) => query['before'] == 11),
      isNotEmpty,
    );
    expect(
      fake.purchaseQueries.every((query) => query['limit'] == 100),
      isTrue,
    );
  });

  testWidgets('a failed older purchases page stays and can be retried', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    fake.purchaseFirstNextBefore = 11;
    fake.purchaseOlderPages[11] = {
      'entries': [_older('pe_page2')],
      'nextBefore': null,
    };
    fake.failOlderRemaining = 1;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.ensureVisible(find.byKey(const Key('purchases-older')));
    await tester.tap(find.byKey(const Key('purchases-older')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('purchases-older-error')), findsOneWidget);
    expect(find.byKey(const Key('purchase-entry-pe_page2')), findsNothing);
    expect(find.byKey(const Key('purchases-older')), findsOneWidget);

    await tester.tap(find.byKey(const Key('purchases-older')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('purchase-entry-pe_page2')), findsOneWidget);
    expect(find.byKey(const Key('purchases-older-error')), findsNothing);
  });

  testWidgets('an older purchases page does not land on another book', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    fake.purchaseFirstNextBefore = 11;
    fake.purchaseOlderPages[11] = {
      'entries': [_older('pe_page2')],
      'nextBefore': null,
    };
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    final gate = Completer<void>();
    fake.pauseGets['/api/purchases/al_bayan'] = gate;
    await tester.ensureVisible(find.byKey(const Key('purchases-older')));
    await tester.tap(find.byKey(const Key('purchases-older')));
    await tester.pump();
    await tester.ensureVisible(find.text(AppStrings.simsim));
    await tester.tap(find.text(AppStrings.simsim));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('purchase-entry-pe_page2')), findsNothing);
    expect(find.text(AppStrings.simsim), findsWidgets);
  });
}

Map<String, dynamic> _older(String id, {int resultUnits = 1}) => {
  'id': id,
  'dayId': '10',
  'sequence': 1,
  'dayNumber': 10,
  'businessDate': '2026-10-17',
  'dayStatus': 'finalized',
  'dayClosingDebtUnits': 1,
  'itemCode': 'custom',
  'itemLabel': 'صفحة أقدم',
  'egpValueUnits': 10,
  'calculationMode': 'divide',
  'exchangeRate': '10',
  'resultUnits': resultUnits,
  'paidUnits': 0,
  'remainingUnits': resultUnits,
  'vodafoneConsumedUnits': 0,
  'actorName': 'مدير تجريبي',
  'actorIsOwner': true,
  'version': 1,
  'dayVersion': 1,
  'correctionOpen': false,
};

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
