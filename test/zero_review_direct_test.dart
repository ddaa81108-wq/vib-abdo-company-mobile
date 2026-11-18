import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show go, loadScreenshotFonts, saveShot;
import 'support/pump_app.dart';

void main() {
  for (final section in [
    'customers',
    'companies',
    'libyan-deposits',
    'egyptian-deposits',
  ]) {
    for (final width in [360.0, 430.0]) {
      testWidgets('$section direct review at $width', (tester) async {
        final layer = await pumpFakeApp(
          tester,
          size: Size(width, 1000),
          textScale: width == 360 ? 1.3 : 1,
        );
        final fake = layer.client as FakeApiClient;
        fake.appendedAccountCards.add((
          section: section,
          card: {
            'id': 'direct_zero',
            'name': 'كارت اختبار مراجعة الصفر',
            'balanceUnits': 0,
            'currency': section == 'egyptian-deposits' ? 'EGP' : 'LYD',
            'version': 3,
            'zeroReview': {'pending': true, 'financialVersion': 8},
          },
        ));
        for (var i = 1; i <= 2; i++) {
          fake.appendedAccountCards.add((
            section: section,
            card: {
              'id': 'zero-next-$i',
              'name': 'مراجعة متتالية $i',
              'balanceUnits': 0,
              'currency': section == 'egyptian-deposits' ? 'EGP' : 'LYD',
              'version': 1,
              'zeroReview': {'pending': true, 'financialVersion': 1},
            },
          ));
        }
        await tester.runAsync(loadScreenshotFonts);
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/$section');
        final check = find.byKey(const ValueKey('zero-review-direct_zero'));
        await tester.ensureVisible(check);
        await tester.pumpAndSettle();
        expect(tester.getSize(check).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(check).height, greaterThanOrEqualTo(48));
        if (width == 430) await saveShot(tester, 'zero-direct-$section-before');
        final gate = Completer<void>();
        fake.pauseMutations = gate;
        await tester.tap(check);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(check);
        await tester.pump();
        expect(find.byKey(Key('screen-$section')), findsOneWidget);
        expect(check, findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          fake.mutationPaths.where((p) => p.endsWith('/zero-review')),
          hasLength(1),
        );
        expect(tester.widget<IconButton>(check).onPressed, isNull);
        gate.complete();
        fake.pauseMutations = null;
        await tester.pumpAndSettle();
        expect(fake.zeroReviewCommits, 1);
        expect(
          fake.mutationBodies.join(),
          contains('"expectedFinancialVersion":8'),
        );
        expect(check, findsNothing);
        expect(
          find.byKey(const Key('account-card-direct_zero')),
          findsOneWidget,
        );
        if (width == 430) await saveShot(tester, 'zero-direct-$section-after');
        final stored = (await tester.runAsync(
          () => fake.get('/api/$section/direct_zero'),
        ))!;
        expect((stored.data as Map)['balanceUnits'], 0);
        for (var i = 1; i <= 2; i++) {
          final next = find.byKey(ValueKey('zero-review-zero-next-$i'));
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(next, findsNothing);
          expect(find.byKey(Key('screen-$section')), findsOneWidget);
        }
        expect(fake.zeroReviewCommits, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
