import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/settings_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('back from a settings page returns to settings, not home', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
    await go(tester, '/settings/users');
    expect(find.byKey(const Key('screen-settings-employees')), findsOneWidget);
    await tester.tap(find.byKey(HomeShell.backKey));
    await settle(tester);
    expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.back));
    await settle(tester);
    expect(find.byKey(SettingsScreen.screenKey), findsNothing);
  });

  testWidgets('logout does not keep a back target into settings', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    await tester.tap(find.byKey(HomeShell.logoutKey));
    await settle(tester);
    await tester.tap(find.byKey(const Key('logout-confirm')));
    await settle(tester);
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeShell.backKey), findsNothing);
  });
}
