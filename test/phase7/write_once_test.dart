import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import '../support/pump_app.dart';

/// P7-20 and P7-21 on the real payment form. The request id is the form
/// lock's id. [FakeApiClient] dedups that id in its ledger store.
void main() {
  testWidgets(
    'P7-21 a second payment tap writes one ledger row',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await _go(tester, '/customers/c_55');
      await tester.tap(find.byKey(const Key('add-payment')));
      await _settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('movement-amount')),
          matching: find.byType(TextField),
        ),
        '10',
      );
      await tester.pump();

      final gate = Completer<void>();
      fake.pauseMutations = gate;
      await tester.tap(find.byKey(const Key('save-movement')));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.tap(find.byKey(const Key('save-movement')));
      await tester.pump();
      expect(fake.mutationRequestIds, hasLength(1));
      final requestId = fake.mutationRequestIds.single;
      gate.complete();
      fake.pauseMutations = null;
      await _settle(tester);

      expect(await _rows(tester, layer), 1);
      await _outsidePump(
        tester,
        () => layer.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          AccountTransactionRequest.partialPayment(
            inputValue: 10,
            date: DateTime.utc(2026, 10, 21),
          ),
          MutationMeta(requestId: requestId, expectedVersion: 4),
        ),
      );
      expect(fake.mutationRequestIds, [requestId]);
      expect(await _rows(tester, layer), 1);
    },
  );

  testWidgets(
    'P7-20 retrying a failed payment reuses the request id and writes one row',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await _go(tester, '/customers/c_55');
      await tester.tap(find.byKey(const Key('add-payment')));
      await _settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('movement-amount')),
          matching: find.byType(TextField),
        ),
        '10',
      );
      await tester.pump();
      fake.failMutationsRemaining = 1;

      await tester.tap(find.byKey(const Key('save-movement')));
      await _settle(tester);
      expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
      expect(await _rows(tester, layer), 0);
      final requestId = fake.mutationRequestIds.single;

      await tester.tap(find.byKey(const Key('save-movement')));
      await _settle(tester);
      expect(fake.mutationRequestIds, [requestId, requestId]);
      expect(await _rows(tester, layer), 1);
    },
  );
}

/// The fake server's zero latency is a timer. Widget tests only fire that
/// timer from [WidgetTester.pump], so repository checks run outside the
/// fake-async zone.
Future<T> _outsidePump<T>(WidgetTester tester, Future<T> Function() body) {
  return tester.runAsync(body).then((value) => value as T);
}

Future<int> _rows(WidgetTester tester, ApiLayer layer) {
  return _outsidePump(tester, () => _partialRows(layer));
}

Future<int> _partialRows(ApiLayer layer) async {
  final page = await layer.accounts.ledger(AccountSection.customers, 'c_55');
  return page.page.items.where((item) => item.id.startsWith('tx_partial')).length;
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
