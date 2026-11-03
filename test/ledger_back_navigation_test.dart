import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

/// Ali, 2026-11-03: back from a ledger returns to the page it was opened
/// from. It never leaves the app.
void main() {
  Future<void> openFromList(WidgetTester tester) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    final card = find.byKey(const Key('account-card-c_55'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await settle(tester);
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
  }

  testWidgets('system back from the ledger returns to the customers list', (
    tester,
  ) async {
    await openFromList(tester);
    final handled = await tester.binding.handlePopRoute();
    await settle(tester);
    expect(handled, isTrue, reason: 'back must not fall through to exit');
    expect(find.byKey(const Key('screen-ledger-customers')), findsNothing);
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
  });

  testWidgets('the ledger back arrow returns to the customers list', (
    tester,
  ) async {
    await openFromList(tester);
    await tester.tap(find.byTooltip(AppStrings.back));
    await settle(tester);
    expect(find.byKey(const Key('screen-ledger-customers')), findsNothing);
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
  });

  testWidgets('system back from a ledger opened by deep link stays in app', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 932));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final handled = await tester.binding.handlePopRoute();
    await settle(tester);
    expect(handled, isTrue);
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
  });

  testWidgets('back twice from a ledger reaches home, not the launcher', (
    tester,
  ) async {
    await openFromList(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.byKey(const Key('screen-customers')), findsNothing);
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
  });
}
