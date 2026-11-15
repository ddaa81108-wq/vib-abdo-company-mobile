import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_drawer.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/account_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  const adminSections = [
    '/purchases',
    '/collections',
    '/settings',
    '/treasury',
    '/customers',
    '/masraweya',
    '/reports',
  ];

  for (final path in adminSections) {
    for (final entry in _LogoutEntry.values) {
      testWidgets(
        'admin logout from $path via ${entry.name} skips the denial',
        (tester) async {
          final layer = await pumpFakeApp(tester, size: const Size(390, 844));
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, path);
          await _logout(tester, entry);
          await _expectDirectLogin(tester, layer);
        },
      );
    }
  }

  for (final entry in _LogoutEntry.values) {
    testWidgets(
      'employee logout from collections via ${entry.name} skips the denial',
      (tester) async {
        final layer = await pumpFakeApp(tester, size: const Size(390, 844));
        await signIn(tester, username: 'employee.demo', password: 'demo-only');
        await go(tester, '/collections');
        await _logout(tester, entry);
        await _expectDirectLogin(tester, layer);
      },
    );
  }
}

enum _LogoutEntry { appBar, drawer, account }

Future<void> _logout(WidgetTester tester, _LogoutEntry entry) async {
  switch (entry) {
    case _LogoutEntry.appBar:
      await _confirm(tester, find.byKey(HomeShell.logoutKey));
    case _LogoutEntry.drawer:
      await tester.tap(find.byTooltip('القائمة'));
      await tester.pumpAndSettle();
      final row = find.byKey(StyledDrawer.logoutKey);
      await tester.ensureVisible(row);
      await _confirm(tester, row);
    case _LogoutEntry.account:
      await go(tester, '/account');
      expect(find.byKey(AccountScreen.screenKey), findsOneWidget);
      final tile = find.byKey(const Key('account-logout'));
      await tester.ensureVisible(tile);
      await _confirm(tester, tile);
  }
}

Future<void> _confirm(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
  expect(find.text(AppStrings.forbidden), findsNothing);
  await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
  // Pump every frame of the wipe. The denial used to appear after
  // permissions were cleared and before the session became signed out.
  for (var i = 0; i < 40; i++) {
    expect(find.text(AppStrings.forbidden), findsNothing);
    expect(find.byKey(const Key('forbidden-pane')), findsNothing);
    expect(find.byKey(const Key('forbidden-snackbar')), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byKey(LoginScreen.screenKey).evaluate().isNotEmpty &&
        find.byKey(HomeShell.shellKey).evaluate().isEmpty) {
      break;
    }
  }
}

Future<void> _expectDirectLogin(WidgetTester tester, ApiLayer layer) async {
  expect(find.text(AppStrings.forbidden), findsNothing);
  expect(find.byKey(const Key('forbidden-pane')), findsNothing);
  expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  expect(find.byKey(HomeShell.shellKey), findsNothing);
  expect(layer.session.state, isA<SessionUnauthenticated>());
  expect((layer.session.state as SessionUnauthenticated).reason, 'logout');
  final router = GoRouter.of(tester.element(find.byType(LoginScreen)));
  expect(router.canPop(), isFalse);
  await tester.binding.handlePopRoute();
  await tester.pump();
  expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  expect(find.text(AppStrings.forbidden), findsNothing);
  expect(tester.takeException(), isNull);
}
