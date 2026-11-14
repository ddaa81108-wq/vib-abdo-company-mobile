import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('094 work table light and dark at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    await tester.ensureVisible(find.byKey(const Key('masraweya-work-table')));
    await tester.pump();
    await saveShot(tester, 'fix094-after-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('masraweya-work-table')));
    await tester.pump();
    await saveShot(tester, 'fix094-after-dark-360');
  }, tags: ['screenshots']);
}
