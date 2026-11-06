import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/login/mfa_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/financial_ledger_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/settings_screen.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'settings, accounts, ledger, security and development at 440x956',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(440, 956));
      await tester.runAsync(loadScreenshotFonts);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        await go(tester, '/settings');
        if (dark) {
          await tester.tap(find.byKey(const Key('settings-theme-switch')));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);
        await saveShot(tester, 'settings-accounts-$theme-440');
        await go(tester, '/settings/users');
        expect(find.byKey(const Key('login-account-create')), findsOneWidget);
        await saveShot(tester, 'login-accounts-$theme-440');
        await go(tester, '/settings/ledger');
        expect(find.byKey(FinancialLedgerScreen.screenKey), findsOneWidget);
        await saveShot(tester, 'financial-ledger-$theme-440');
        await go(tester, '/settings/audit');
        expect(
          find.byKey(const Key('security-current-session')),
          findsOneWidget,
        );
        await saveShot(tester, 'security-audit-$theme-440');
        await go(tester, '/settings/development');
        expect(
          find.byKey(const Key('development-app-version')),
          findsOneWidget,
        );
        await saveShot(tester, 'development-$theme-440');
      }
    },
    tags: ['screenshots'],
  );

  testWidgets(
    'mfa challenge and security notes at 440x956',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(440, 956));
      await tester.runAsync(loadScreenshotFonts);
      await signIn(tester, username: 'mfa.admin', password: 'demo-only');
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        expect(find.byKey(MfaScreen.screenKey), findsOneWidget);
        expect(find.byKey(MfaScreen.codeKey), findsOneWidget);
        if (dark) {
          await tester.tap(find.byKey(const Key('mfa-theme')));
          await tester.pumpAndSettle();
        }
        await saveShot(tester, 'mfa-challenge-$theme-440');
      }
    },
    tags: ['screenshots'],
  );
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
