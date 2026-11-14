import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('each section shows آخر حركة from its own list card', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 1200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    const expected = {
      '/customers': '2026/10/18',
      '/companies': '2026/10/19',
      '/libyan-deposits': '2026/10/17',
      '/egyptian-deposits': '2026/10/21',
    };
    for (final entry in expected.entries) {
      await go(tester, entry.key);
      final text = tester
          .widget<Text>(find.byKey(const Key('account-movement-c_55')))
          .data!;
      expect(
        text.startsWith(AppStrings.lastActivity),
        isTrue,
        reason: entry.key,
      );
      expect(text.contains('—'), isFalse, reason: entry.key);
      expect(text.contains(entry.value), isTrue, reason: '$entry $text');
    }
  });
}
