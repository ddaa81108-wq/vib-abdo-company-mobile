import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('095 and 096 frames at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await saveShot(tester, 'fix095-purchases-open-light');
    await tester.ensureVisible(find.byKey(const Key('purchase-kind-fawry')));
    await tester.tap(
      find.byKey(const Key('purchase-kind-fawry')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('purchase-field-value')),
      '100',
    );
    await tester.enterText(find.byKey(const Key('purchase-field-rate')), '10');
    await tester.enterText(find.byKey(const Key('purchase-field-paid')), '0');
    await tester.ensureVisible(find.byKey(const Key('save-purchase')));
    await tester.tap(
      find.byKey(const Key('save-purchase')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await saveShot(tester, 'fix095-purchases-saved-pencil');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await saveShot(tester, 'fix095-purchases-saved-dark');
    await tester.tap(find.byKey(HomeShell.logoutKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await saveShot(tester, 'fix096-logout-confirm');
    await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(LoginScreen.screenKey).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    await saveShot(tester, 'fix096-login-after-logout');
  }, tags: ['screenshots']);
}
