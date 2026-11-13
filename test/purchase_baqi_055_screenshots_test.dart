import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  testWidgets('purchases 055 screenshots', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> ledger(Size size, String name) async {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      await tester.scrollUntilVisible(
        find.byKey(const Key('purchase-balance-pe_old')),
        40,
        scrollable: _vertical,
      );
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
          find.byKey(const Key('purchase-balance-pe_1')),
          40,
          scrollable: horizontal,
        );
      }
      await saveShot(tester, name);
    }

    await ledger(const Size(1280, 980), 'baqi-055-ledger-wide');
    await ledger(const Size(360, 800), 'baqi-055-ledger-360');

    Future<void> typing(Size size, String name) async {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      await tester.enterText(
        find.byKey(const Key('purchase-field-value')),
        '1000',
      );
      await tester.enterText(
        find.byKey(const Key('purchase-field-rate')),
        '10',
      );
      await tester.pump();
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
          find.byKey(const Key('purchase-preview-balance')),
          40,
          scrollable: horizontal,
        );
      }
      await saveShot(tester, name);
    }

    await typing(const Size(1280, 980), 'baqi-055-typing-wide');
    await typing(const Size(360, 800), 'baqi-055-typing-360');

    Future<void> partial(Size size, String name) async {
      final layer = await pumpFakeApp(tester, size: size);
      (layer.client as FakeApiClient).purchaseFirstNextBefore = 11;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      await tester.scrollUntilVisible(
        find.byKey(const Key('purchase-prior-row')),
        40,
        scrollable: _vertical,
      );
      await saveShot(tester, name);
    }

    await partial(const Size(1280, 980), 'baqi-055-partial-wide');
    await partial(const Size(360, 800), 'baqi-055-partial-360');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

final _vertical = find.descendant(
  of: find.byKey(const Key('screen-purchases')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  ),
);
