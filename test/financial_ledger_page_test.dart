import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('a failed older ledger page keeps the current page totals', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1600));
    final fake = layer.client as FakeApiClient;
    fake.financialLedgerFirstNextBefore = 'p2';
    fake.financialLedgerOlderPages['p2'] = _olderPage();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/ledger');
    expect(find.byKey(const Key('ledger-entry-4')), findsOneWidget);
    expect(find.textContaining('480'), findsWidgets);
    fake.failOlderRemaining = 1;

    await _show(tester, find.byKey(const Key('ledger-older')));
    await tester.tap(find.byKey(const Key('ledger-older')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ledger-older-error')), findsOneWidget);
    expect(find.byKey(const Key('ledger-entry-4')), findsOneWidget);
    expect(find.byKey(const Key('ledger-entry-90')), findsNothing);
    expect(find.textContaining('480'), findsWidgets);
    expect(find.textContaining('485'), findsNothing);

    await tester.tap(find.byKey(const Key('ledger-older')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger-entry-90')), findsOneWidget);
    expect(find.byKey(const Key('ledger-entry-4')), findsNothing);
    expect(find.textContaining('480'), findsNothing);
    expect(find.textContaining('5 د.ل'), findsWidgets);
    expect(find.textContaining('485'), findsNothing);
    expect(find.byKey(const Key('ledger-older-error')), findsNothing);
  });

  testWidgets('a ledger page that arrives after a new filter is dropped', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1600));
    final fake = layer.client as FakeApiClient;
    fake.financialLedgerFirstNextBefore = 'p2';
    fake.financialLedgerOlderPages['p2'] = _olderPage();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/ledger');
    final gate = Completer<void>();
    fake.pauseGets['/api/financial-ledger'] = gate;
    await _show(tester, find.byKey(const Key('ledger-older')));
    await tester.tap(find.byKey(const Key('ledger-older')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ledger-search')), 'zzz-none');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ledger-entry-90')), findsNothing);
    expect(find.byKey(const Key('ledger-entry-4')), findsNothing);
  });
}

Map<String, dynamic> _olderPage() => {
  'items': [
    {
      'id': 90,
      'sectionKey': 'treasury',
      'sourceStatus': 'posted',
      'counterpartyName': 'صفحة أقدم',
      'referenceNo': 'OLD-1',
      'currency': 'LYD',
      'amountUnits': 5,
      'effectUnits': 5,
      'actorName': 'مدير تجريبي',
    },
  ],
  'pageTotals': {'LYD': 5},
  'nextBefore': null,
};

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('screen-financial-ledger')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
