import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('090 active day pencil and X, light and dark', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    for (final amount in ['100', '200', '300']) {
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

    Future<void> showActions() async {
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('purchase-ledger-scroll')),
      );
      scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
      await tester.pump();
    }

    await showActions();
    await saveShot(tester, 'fix090-active-day-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await showActions();
    await saveShot(tester, 'fix090-active-day-dark-360');
    await tester.ensureVisible(find.byKey(const Key('edit-pe_new_2')));
    await tester.tap(find.byKey(const Key('edit-pe_new_2')));
    await tester.pumpAndSettle();
    await showActions();
    await saveShot(tester, 'fix090-edit-row-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await showActions();
    await saveShot(tester, 'fix090-edit-row-light-360');
  }, tags: ['screenshots']);
}
