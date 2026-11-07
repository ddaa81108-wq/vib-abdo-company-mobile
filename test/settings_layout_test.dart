import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/settings/settings_screen.dart';

import 'support/pump_app.dart';

// Ali, 2026-11-04: settings as the website's card list.
void main() {
  for (final scale in const [1.0, 1.6]) {
    testWidgets('settings cards, header and local theme switch x$scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFakeApp(tester, size: const Size(430, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/settings');
      expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('settings-header')), findsOneWidget);
      for (final key in const [
        'settings-link-employees',
        'settings-link-account',
        'settings-theme',
        'financial-ledger',
        'settings-about',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      // Placeholders are not linked.
      expect(find.byKey(const Key('settings-link-audit')), findsNothing);
      // Theme switch is local and flips the app theme.
      final before = Theme.of(
        tester.element(find.byKey(SettingsScreen.screenKey)),
      ).brightness;
      await tester.tap(find.byKey(const Key('settings-theme-switch')));
      await settle(tester);
      final after = Theme.of(
        tester.element(find.byKey(SettingsScreen.screenKey)),
      ).brightness;
      expect(after, isNot(before));
      // The account card opens حسابي.
      await tester.tap(find.byKey(const Key('settings-link-account')));
      await settle(tester);
      expect(find.byKey(const Key('screen-account')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
