import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';

import 'support/pump_app.dart';
import 'support/phase7_ui.dart';
import 'shell_screenshots_test.dart' show saveShot, loadScreenshotFonts;
import 'transaction_correction_test.dart' as correction;

void main() {
  for (final route in [
    '/companies/c_co_02',
    '/libyan-deposits/c_55',
    '/egyptian-deposits/c_eg_08',
  ]) {
    for (final dark in [false, true]) {
      testWidgets('$route ${dark ? "night" : "day"} records and row editing', (
        tester,
      ) async {
        await pumpFakeApp(tester, size: const Size(390, 900));
        await tester.runAsync(loadScreenshotFonts);
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await settle(tester);
        }
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, route);
        final name = route.split('/')[1];
        final mode = dark ? 'night' : 'day';
        await saveShot(tester, 'shared-$name-$mode');
        await settle(tester);
        await correction.tapCorrect(tester, 'tx_1');
        final amount = find.byKey(const Key('correction-amount'));
        expect(amount.hitTestable(), findsOneWidget);
        final row = tester.getRect(find.byKey(const Key('ledger-row-tx_1')));
        expect(row.height, lessThan(150));
        await saveShot(tester, 'shared-$name-$mode-edit');
        await settle(tester);
        await correction.closeCorrection(tester, 'tx_1');
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
