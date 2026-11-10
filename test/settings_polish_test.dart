import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/mfa_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/financial_ledger_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/login_accounts_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/security_screen.dart';

import 'settings_accounts_screenshots_test.dart' show go;
import 'support/pump_app.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('settings and MFA hold at 360dp and text scale $scale', (
      tester,
    ) async {
      await pumpFakeApp(tester, size: const Size(360, 740), textScale: scale);
      await signIn(tester, username: 'mfa.admin', password: 'demo-only');
      expect(find.byKey(MfaScreen.screenKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(MfaScreen.cancelKey));
      await tester.tap(find.byKey(MfaScreen.cancelKey));
      await tester.pumpAndSettle();
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(tester.takeException(), isNull, reason: 'home');
      await go(tester, '/settings/users');
      expect(find.byKey(const Key('login-account-create')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'users');
      await go(tester, '/settings/users/new');
      expect(find.byKey(LoginAccountCreateScreen.screenKey), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'create');
      await go(tester, '/settings/audit');
      expect(find.byKey(SecurityScreen.screenKey), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'audit');
      await go(tester, '/settings/ledger');
      expect(find.byKey(FinancialLedgerScreen.screenKey), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'ledger');
    });
  }
}
