import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_drawer.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/account_screen.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('app bar logout clears the session and the back stack', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    await go(tester, '/purchases');
    await _confirmLogout(tester, find.byKey(HomeShell.logoutKey));
    await _expectLoggedOut(tester, layer);
  });

  testWidgets('drawer logout clears the session and the back stack', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    await tester.tap(find.byTooltip('القائمة'));
    await tester.pumpAndSettle();
    final row = find.byKey(StyledDrawer.logoutKey);
    await tester.ensureVisible(row);
    await _confirmLogout(tester, row);
    await _expectLoggedOut(tester, layer);
  });

  testWidgets('account logout clears the session and the back stack', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/account');
    expect(find.byKey(AccountScreen.screenKey), findsOneWidget);
    final tile = find.byKey(const Key('account-logout'));
    await tester.ensureVisible(tile);
    await _confirmLogout(tester, tile);
    await _expectLoggedOut(tester, layer);
  });

  testWidgets('logout still reaches login when the request fails offline', (
    tester,
  ) async {
    final link = ToggleConnectivity(true);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      connectivity: link,
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    link.setOnline(false);
    (layer.client as FakeApiClient).failLogout = true;
    await go(tester, '/purchases');
    await _confirmLogout(tester, find.byKey(HomeShell.logoutKey));
    await _expectLoggedOut(tester, layer);
  });
}

Future<void> _confirmLogout(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
  await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
  await tester.pumpAndSettle();
}

Future<void> _expectLoggedOut(WidgetTester tester, ApiLayer layer) async {
  expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  expect(find.byKey(HomeShell.shellKey), findsNothing);
  expect(layer.session.state, isA<SessionUnauthenticated>());
  expect((layer.session.state as SessionUnauthenticated).reason, 'logout');
  final router = GoRouter.of(tester.element(find.byType(LoginScreen)));
  expect(router.canPop(), isFalse);
  await tester.binding.handlePopRoute();
  await tester.pump();
  expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  expect(find.byKey(HomeShell.shellKey), findsNothing);
  expect(tester.takeException(), isNull);
}
