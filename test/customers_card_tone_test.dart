import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/customer_card_tone.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  test('the balance sign picks the word and colour kind', () {
    expect(
      customerBalanceKind(const MoneyValue.known(5)),
      CustomerBalanceKind.debt,
    );
    expect(
      customerBalanceKind(const MoneyValue.known(-5)),
      CustomerBalanceKind.credit,
    );
    expect(
      customerBalanceKind(const MoneyValue.known(0)),
      CustomerBalanceKind.zero,
    );
    expect(customerBalanceKind(null), CustomerBalanceKind.unknown);
  });

  testWidgets('customer toolbar controls share one height', (tester) async {
    for (final size in [const Size(430, 932), const Size(320, 900)]) {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers');
      final heights = {
        for (final key in ['add-account', 'account-search', 'assign-mode'])
          tester.getSize(find.byKey(Key(key))).height.roundToDouble(),
      };
      expect(heights, hasLength(1), reason: '$size $heights');
      expect(tester.takeException(), isNull);
    }
  });
}
