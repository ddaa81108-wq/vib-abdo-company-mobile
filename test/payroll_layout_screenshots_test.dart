import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'shell_screenshots_test.dart' show saveShot, loadScreenshotFonts;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets(
    'payroll directory and independent employee page fit phone widths in both themes',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 1050));
      await tester.runAsync(loadScreenshotFonts);
      await signIn(tester, username: 'admin.demo', password: 'test-only');
      await go(tester, '/collections?view=payroll');
      for (final dark in [false, true]) {
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const Key('home-shell'))),
        );
        container.read(themeModeProvider.notifier).setDark(dark);
        await settle(tester);
        await saveShot(tester, 'payroll-directory-${dark ? 'dark' : 'light'}');
        await tester.tap(find.byKey(const Key('payroll-employee-u_12')));
        await settle(tester);
        await saveShot(tester, 'payroll-employee-${dark ? 'dark' : 'light'}');
        for (final width in [320.0, 360.0, 390.0, 600.0]) {
          tester.view.physicalSize = Size(width, 1050);
          await settle(tester);
          expect(find.byKey(const Key('payroll-page-u_12')), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'width=$width dark=$dark',
          );
        }
        tester.view.physicalSize = const Size(390, 1050);
        await tester.ensureVisible(
          find.byKey(const Key('payroll-employees-back')),
        );
        await tester.tap(find.byKey(const Key('payroll-employees-back')));
        await settle(tester);
      }
    },
    tags: const ['screenshots'],
  );
}
