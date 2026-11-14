import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('091 purchase save has no server-reply banner', (tester) async {
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
      await tester.enterText(
        find.byKey(const Key('purchase-field-rate')),
        '10',
      );
      await tester.enterText(
        find.byKey(const Key('purchase-field-paid')),
        '10',
      );
      await tester.ensureVisible(find.byKey(const Key('save-purchase')));
      await tester.tap(find.byKey(const Key('save-purchase')));
      await tester.pumpAndSettle();
    }

    await saveRow('100');
    await saveShot(tester, 'fix091-purchase-saved-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveRow('200');
    await saveShot(tester, 'fix091-purchase-saved-dark-360');
  }, tags: ['screenshots']);
}
