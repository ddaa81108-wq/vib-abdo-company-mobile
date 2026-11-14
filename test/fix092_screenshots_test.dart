import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('092 active-day pencil stays on screen', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    Future<void> saveRow(String amount) async {
      await tester.ensureVisible(find.byKey(const Key('purchase-kind-fawry')));
      await tester.tap(find.byKey(const Key('purchase-kind-fawry')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('purchase-field-value')),
        amount,
      );
      await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
      await tester.enterText(find.byKey(const Key('purchase-field-paid')), '10');
      await tester.ensureVisible(find.byKey(const Key('save-purchase')));
      await tester.tap(find.byKey(const Key('save-purchase')));
      await tester.pumpAndSettle();
    }

    for (final amount in ['100', '200', '300']) {
      await saveRow(amount);
    }
    await saveShot(tester, 'fix092-01-three-rows');
    await tester.tap(find.byKey(const Key('edit-pe_new_1')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix092-02-editing');
    await tester.enterText(find.byKey(const Key('purchase-field-paid')), '25');
    await tester.ensureVisible(find.byKey(const Key('save-purchase')));
    await tester.tap(find.byKey(const Key('save-purchase')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix092-03-saved');
  }, tags: ['screenshots']);
}
