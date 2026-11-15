import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'support/pump_app.dart';
import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;

void main() {
  testWidgets('logout then login works repeatedly without restarting the app', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadScreenshotFonts();
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        await ui.loadFontFromList(
          await File('assets/fonts/Cairo-$weight.ttf').readAsBytes(),
          fontFamily: 'Cairo',
        );
      }
    });
    final layer = await pumpFakeApp(tester, size: const Size(390, 844));
    for (var cycle = 0; cycle < 3; cycle++) {
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(layer.session.state, isA<SessionAuthenticated>());
      await tester.tap(find.byKey(HomeShell.logoutKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
      expect(layer.session.state, isA<SessionUnauthenticated>());
      expect(layer.session.signingOut, isFalse);
      expect(tester.takeException(), isNull);
      if (cycle == 0) await saveShot(tester, 'logout-fixed-login');
    }
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);
    expect(layer.session.state, isA<SessionAuthenticated>());
    await saveShot(tester, 'logout-fixed-relogin');
  });
}
