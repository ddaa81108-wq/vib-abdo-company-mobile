import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  testWidgets('purchases tick screenshots', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shot(Size size, String name) async {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      final horizontal = find.descendant(
        of: find.byKey(const Key('purchase-ledger')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('purchase-entry-pe_old')),
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
      if (horizontal.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('save-purchase')),
          30,
          scrollable: horizontal,
        );
      }
      await saveShot(tester, name);
    }

    await shot(const Size(1280, 900), 'baqi-056-after-wide');
    await shot(const Size(360, 800), 'baqi-056-after-360');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}
