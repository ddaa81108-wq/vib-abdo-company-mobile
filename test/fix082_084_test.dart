import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/website_account_card.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('light cards are cream and egyptian deposits stay one per row', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      for (final width in [360.0, 430.0, 800.0]) {
        await pumpFakeApp(tester, size: Size(width, 900));
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        if (dark) {
          await tester.tap(find.byKey(const Key('app-bar-theme')));
          await tester.pumpAndSettle();
        }
        for (final path in const [
          '/customers',
          '/companies',
          '/libyan-deposits',
          '/egyptian-deposits',
        ]) {
          await go(tester, path);
          final ink = tester.widget<Ink>(
            find.descendant(
              of: find.byKey(const Key('account-card-c_55')),
              matching: find.byType(Ink),
            ),
          );
          final box = ink.decoration! as BoxDecoration;
          if (dark) {
            expect(box.gradient, isNotNull, reason: '$path $width dark');
          } else {
            expect(box.color, websiteCardLightFill, reason: '$path $width');
          }
        }
        await go(tester, '/egyptian-deposits');
        final first = tester.getRect(
          find.byKey(const Key('account-card-c_55')),
        );
        final second = tester.getRect(
          find.byKey(const Key('account-card-c_eg_02')),
        );
        expect(second.top, greaterThan(first.bottom - 1));
        expect(first.width, greaterThan(width * 0.7));
        expect((first.width - second.width).abs(), lessThan(2));
      }
    }
  });

  testWidgets('deposit header controls are equal rounded rectangles', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 956), textScale: 1.3);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    for (final path in ['/libyan-deposits', '/egyptian-deposits']) {
      await go(tester, path);
      final total = tester.getRect(find.byKey(const Key('deposit-total-pill')));
      final active = tester.getRect(
        find.byKey(const Key('deposit-active-pill')),
      );
      final add = tester.getRect(find.byKey(const Key('add-account')));
      expect((total.height - active.height).abs(), lessThan(1));
      expect((total.height - add.height).abs(), lessThan(1));
      expect((total.width - active.width).abs(), lessThan(8));
      expect((total.width - add.width).abs(), lessThan(8));
      expect(total.height, lessThan(56));
      final shape = Theme.of(
        tester.element(find.byKey(const Key('add-account'))),
      ).filledButtonTheme.style!.shape!.resolve({});
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
    }
  });
}
