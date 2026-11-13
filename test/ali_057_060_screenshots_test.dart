import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  testWidgets('057-060 after screenshots', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> open(Size size, String path) async {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, path);
    }

    await open(const Size(1280, 900), '/purchases');
    final horizontal = find.descendant(
      of: find.byKey(const Key('purchase-ledger')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
      ),
    );
    if (horizontal.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(const Key('edit-pe_1')),
        40,
        scrollable: horizontal,
      );
    }
    await saveShot(tester, 'fix057-after-wide');

    await open(const Size(360, 800), '/purchases');
    final horizontalPhone = find.descendant(
      of: find.byKey(const Key('purchase-ledger')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
      ),
    );
    if (horizontalPhone.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(const Key('edit-pe_1')),
        40,
        scrollable: horizontalPhone,
      );
    }
    await saveShot(tester, 'fix057-after-360');

    Future<void> showWork(String name) async {
      final valueField = find.byKey(const Key('masraweya-entry-value-field-0'));
      await tester.ensureVisible(valueField);
      await tester.enterText(valueField, '999999999999');
      await tester.pump();
      await tester.ensureVisible(valueField);
      await tester.pump();
      await saveShot(tester, name);
    }

    await open(const Size(1280, 900), '/masraweya');
    await showWork('fix058-after-wide');
    await open(const Size(360, 800), '/masraweya');
    await showWork('fix058-after-360');
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(const Size(360, 800), '/masraweya');
    await showWork('fix058-after-360-x2');
    tester.platformDispatcher.clearTextScaleFactorTestValue();

    await open(const Size(1280, 900), '/customers/c_55');
    await saveShot(tester, 'fix060-after-wide');
    await open(const Size(360, 800), '/customers/c_55');
    await saveShot(tester, 'fix060-after-360');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}
