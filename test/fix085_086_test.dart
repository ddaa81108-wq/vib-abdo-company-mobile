import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  const paths = <String, (String, String)>{
    '/customers': ('c_55', 'c_56'),
    '/companies': ('c_55', 'c_co_02'),
    '/libyan-deposits': ('c_55', 'c_ly_02'),
    '/egyptian-deposits': ('c_55', 'c_eg_02'),
  };

  testWidgets('every section is one full-width card per row', (tester) async {
    for (final dark in [false, true]) {
      for (final width in [360.0, 430.0, 800.0]) {
        await pumpFakeApp(tester, size: Size(width, 1200));
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        if (dark) {
          await tester.tap(find.byKey(const Key('app-bar-theme')));
          await tester.pumpAndSettle();
        }
        for (final entry in paths.entries) {
          await go(tester, entry.key);
          final first = tester.getRect(
            find.byKey(Key('account-card-${entry.value.$1}')),
          );
          final second = tester.getRect(
            find.byKey(Key('account-card-${entry.value.$2}')),
          );
          expect(
            second.top,
            greaterThan(first.bottom - 1),
            reason: '${entry.key} $width dark=$dark',
          );
          expect(first.width, greaterThan(width * 0.7));
          expect((first.width - second.width).abs(), lessThan(2));
        }
      }
    }
  });

  testWidgets('card text starts at the top and the pin sits in the corner', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pumpFakeApp(tester, size: const Size(360, 1200));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      if (dark) {
        await tester.tap(find.byKey(const Key('app-bar-theme')));
        await tester.pumpAndSettle();
      }
      for (final path in paths.keys) {
        await go(tester, path);
        final card = tester.getRect(find.byKey(const Key('account-card-c_55')));
        final status = tester.getRect(
          find.byKey(const Key('account-age-c_55')),
        );
        final pin = tester.getRect(find.byKey(const Key('pin-c_55')));
        final chip = find.byKey(const Key('account-assignee-c_55'));
        final first = chip.evaluate().isEmpty ? status : tester.getRect(chip);
        expect(first.top - card.top, lessThan(22), reason: path);
        expect(pin.top - card.top, lessThan(22), reason: path);
        expect(first.top, lessThan(pin.bottom), reason: path);
        expect(pin.left, greaterThanOrEqualTo(card.left - 1));
        expect(pin.right, lessThanOrEqualTo(card.right + 1));
        if (chip.evaluate().isEmpty) {
          expect(status.top - card.top, lessThan(22), reason: path);
        } else {
          expect(status.top, greaterThan(first.bottom - 1), reason: path);
          expect(status.top - first.bottom, lessThan(16), reason: path);
        }
      }
    }
  });
}
