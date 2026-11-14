import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import '../test/support/phase7_nav.dart';
import '../test/support/pump_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('purchases save then logout stays on login', (tester) async {
    await pumpFakeApp(tester, size: const Size(1080, 2280));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.pump(const Duration(seconds: 1));
    final kind = find.byKey(const Key('purchase-kind-fawry'));
    if (kind.evaluate().isNotEmpty) {
      await tester.tap(kind, warnIfMissed: false);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('purchase-field-value')),
        '100',
      );
      await tester.enterText(
        find.byKey(const Key('purchase-field-rate')),
        '10',
      );
      await tester.enterText(find.byKey(const Key('purchase-field-paid')), '0');
      await tester.tap(
        find.byKey(const Key('save-purchase')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.byKey(HomeShell.logoutKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(LogoutConfirmDialog.confirmKey).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.ensureVisible(find.byKey(LogoutConfirmDialog.confirmKey));
    await tester.tap(
      find.byKey(LogoutConfirmDialog.confirmKey),
      warnIfMissed: false,
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(LoginScreen.screenKey).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  });
}
