import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('every saved active-day row keeps pencil and X after reload', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1100, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_old')), findsOneWidget);

    for (final amount in ['100', '200', '300']) {
      await _saveRow(tester, amount);
    }
    for (final id in ['pe_1', 'pe_new_1', 'pe_new_2', 'pe_new_3']) {
      expect(find.byKey(Key('edit-$id')), findsOneWidget, reason: id);
      expect(find.byKey(Key('delete-$id')), findsOneWidget, reason: id);
      expect(find.byKey(Key('purchase-saved-mark-$id')), findsNothing);
    }
    expect(find.byKey(const Key('purchase-saved-mark-pe_old')), findsOneWidget);

    await go(tester, '/');
    await go(tester, '/purchases');
    for (final id in ['pe_1', 'pe_new_1', 'pe_new_2', 'pe_new_3']) {
      expect(find.byKey(Key('edit-$id')), findsOneWidget, reason: 'reload $id');
      expect(find.byKey(Key('delete-$id')), findsOneWidget);
    }

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('purchase-ledger-scroll')),
    );
    scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-pe_new_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-purchase')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_new_2')), findsNothing);
    expect(find.byKey(const Key('edit-pe_new_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _saveRow(WidgetTester tester, String amount) async {
  await tester.ensureVisible(find.byKey(const Key('purchase-kind-fawry')));
  await tester.tap(find.byKey(const Key('purchase-kind-fawry')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('purchase-field-value')), amount);
  await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
  await tester.enterText(find.byKey(const Key('purchase-field-paid')), '10');
  await tester.ensureVisible(find.byKey(const Key('save-purchase')));
  await tester.tap(find.byKey(const Key('save-purchase')));
  await tester.pumpAndSettle();
}
