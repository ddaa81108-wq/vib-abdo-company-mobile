import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import '../support/pump_app.dart';

/// P7-02 through the real login form and [LoginController]. The session
/// provider is not overridden. The server is [FakeApiClient].
void main() {
  testWidgets(
    'P7-02 the login form signs in and a wrong password stays on the form',
    (tester) async {
      final layer = await pumpFakeApp(tester);
      final fake = layer.client as FakeApiClient;

      await signIn(tester, username: 'admin.demo', password: 'wrong');
      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
      expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
      expect(layer.session.state, isNot(isA<SessionAuthenticated>()));

      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.byKey(HomeShell.shellKey), findsOneWidget);
      expect(layer.session.state, isA<SessionAuthenticated>());
      expect(
        fake.lastRequestHeaders.keys.map((key) => key.toLowerCase()),
        contains('cookie'),
      );

      await tester.tap(find.byKey(HomeShell.logoutKey));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.logoutConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('logout-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(LoginScreen.submitKey), findsOneWidget);
      expect(
        fake.lastRequestHeaders.keys.map((key) => key.toLowerCase()),
        contains('x-csrf-token'),
      );
      expect(layer.session.state, isA<SessionUnauthenticated>());
    },
  );
}
