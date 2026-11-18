import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';

import 'support/pump_app.dart';
import 'support/phase7_ui.dart' show settle;
import 'shell_screenshots_test.dart' show go, loadScreenshotFonts, saveShot;

void main() {
  const suffix = String.fromEnvironment(
    'LEDGER_SHOT_SUFFIX',
    defaultValue: 'after',
  );
  for (final dark in [false, true]) {
    for (final width in [390.0, 430.0]) {
      testWidgets('customer ledger ${dark ? "night" : "day"} $width', (
        tester,
      ) async {
        await pumpFakeApp(tester, size: Size(width, 900));
        await tester.runAsync(loadScreenshotFonts);
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await tester.pumpAndSettle();
        }
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/customers/c_55');
        expect(find.byKey(const Key('ledger-header-balance')), findsOneWidget);
        expect(find.byKey(const Key('ledger-column-header')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await saveShot(
          tester,
          'customer-ledger-$suffix-${dark ? "night" : "day"}-${width.toInt()}',
        );
        await settle(tester);
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
