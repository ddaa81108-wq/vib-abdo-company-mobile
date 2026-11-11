import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  testWidgets('purchases running balance screenshots', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(1280, 980));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-balance-pe_old')),
      40,
      scrollable: find.descendant(
        of: find.byKey(const Key('screen-purchases')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    await saveShot(tester, 'baqi-054-app-after-wide');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-balance-pe_old')),
      40,
      scrollable: find.descendant(
        of: find.byKey(const Key('screen-purchases')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      ),
    );
    await saveShot(tester, 'baqi-054-app-after-360');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}
