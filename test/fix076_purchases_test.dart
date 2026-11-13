import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('a confirmed active-day row becomes pencil and trash', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_1')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_1')), findsNothing);
    expect(find.byKey(const Key('purchase-saved-mark-pe_old')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('purchase-kind-fawry')));
    await tester.tap(find.byKey(const Key('purchase-kind-fawry')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('purchase-field-value')),
      '1000',
    );
    await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
    await tester.enterText(find.byKey(const Key('purchase-field-paid')), '50');
    await tester.ensureVisible(find.byKey(const Key('save-purchase')));
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-pe_new')), findsOneWidget);
    expect(find.byKey(const Key('delete-pe_new')), findsOneWidget);
    expect(find.byKey(const Key('purchase-saved-mark-pe_new')), findsNothing);
    expect(find.byKey(const Key('purchase-saved-mark-pe_old')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
