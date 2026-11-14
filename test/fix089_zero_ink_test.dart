import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  test('zero ink is أسمر and debt and أمانة stay put', () {
    expect(websiteCardZeroLight, const Color(0xFF4A3728));
    expect(websiteCardZeroDark, const Color(0xFFD7C4A8));
    expect(
      websiteCardNatureInk(AccountSection.customers, 320),
      const Color(0xFFB42318),
    );
    expect(
      websiteCardNatureInk(AccountSection.customers, -80),
      const Color(0xFF0E7A45),
    );
    expect(
      websiteCardNatureInk(AccountSection.libyanDeposits, 0),
      websiteCardZeroLight,
    );
  });

  testWidgets('a zero card uses أسمر text and border, debt stays red', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    _expectZero(tester, light: true);
    _expectDebt(tester, const Color(0xFFB42318));
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    _expectZero(tester, light: false);
    final debtName = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('account-card-c_55')),
        matching: find.text('عميل تجريبي'),
      ),
    );
    expect(debtName.style?.color, Colors.white);
  });
}

void _expectZero(WidgetTester tester, {required bool light}) {
  final ink = websiteCardZeroInk(light: light);
  final status = tester.widget<Text>(find.byKey(const Key('account-age-c_57')));
  final name = tester.widget<Text>(find.text('عميل تجريبي ٣'));
  final movement = tester.widget<Text>(
    find.byKey(const Key('account-movement-c_57')),
  );
  expect(status.style?.color, ink);
  expect(name.style?.color, ink);
  expect(movement.style?.color, ink.withValues(alpha: 0.92));
  final box =
      tester
              .widget<Ink>(
                find.descendant(
                  of: find.byKey(const Key('account-card-c_57')),
                  matching: find.byType(Ink),
                ),
              )
              .decoration!
          as BoxDecoration;
  if (light) {
    expect(box.border?.top.color, ink);
  } else {
    expect(box.border?.top.color, const Color(0xFFEAC04A));
  }
}

void _expectDebt(WidgetTester tester, Color ink) {
  final status = tester.widget<Text>(find.byKey(const Key('account-age-c_55')));
  expect(status.style?.color, ink);
}
