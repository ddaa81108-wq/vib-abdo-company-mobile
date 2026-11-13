import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('082-084 light and dark at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    for (final path in const [
      'customers',
      'companies',
      'libyan-deposits',
      'egyptian-deposits',
    ]) {
      await go(tester, '/$path');
      await saveShot(tester, 'fix082-084-$path-light-360');
      await tester.tap(find.byKey(const Key('app-bar-theme')));
      await tester.pumpAndSettle();
      await saveShot(tester, 'fix082-084-$path-dark-360');
      await tester.tap(find.byKey(const Key('app-bar-theme')));
      await tester.pumpAndSettle();
    }
  }, tags: ['screenshots']);
}
