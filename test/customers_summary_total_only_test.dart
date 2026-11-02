import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('customers summary shows only total debt, not the net', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    final card = find.byKey(const Key('summary-total-only'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(AppStrings.totalDebt)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.netDebt), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('companies keep net and total', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    expect(find.byKey(const Key('summary-total-only')), findsNothing);
    expect(find.text(AppStrings.netDebt), findsOneWidget);
  });
}
