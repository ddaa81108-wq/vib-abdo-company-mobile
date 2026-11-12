import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  testWidgets('064 ledger header and total at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetViewPadding);
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await tester.pump(const Duration(milliseconds: 50));
    await saveShot(tester, 'fix064-after-360');
  }, tags: const ['screenshots']);
}
