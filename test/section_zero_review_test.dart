import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  for (final sample in const [
    ('companies', '/companies', 'c_co_02', 'LYD'),
    ('libyan-deposits', '/libyan-deposits', 'c_ly_02', 'LYD'),
    ('egyptian-deposits', '/egyptian-deposits', 'c_eg_02', 'EGP'),
  ]) {
    testWidgets('${sample.$1} confirms from the preview and then refetches', (
      tester,
    ) async {
      final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
      final fake = layer.client as FakeApiClient;
      fake.appendedAccountCards.add((
        section: sample.$1,
        card: {
          'id': 'z_new',
          'name': 'صفر جديد',
          'balanceUnits': 0,
          'currency': sample.$4,
          'version': 5,
          'zeroReview': {
            'pending': true,
            'financialVersion': 2,
            'reviewedAt': null,
            'reviewedByName': null,
          },
        },
      ));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, sample.$2);
      expect(_before(tester, 'z_new', sample.$3), isTrue);
      await tester.tap(find.byKey(const ValueKey('zero-review-z_new')));
      await tester.pumpAndSettle();
      expect(fake.mutationBodies, isEmpty);
      await tester.tap(find.byKey(const Key('zero-preview-cancel')));
      await tester.pumpAndSettle();
      expect(fake.mutationPaths, isEmpty);
      expect(_before(tester, 'z_new', sample.$3), isTrue);

      await tester.tap(find.byKey(const ValueKey('zero-review-z_new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('zero-preview-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('zero-review-z_new')), findsNothing);
      expect(_before(tester, sample.$3, 'z_new'), isTrue);
      expect(fake.mutationPaths.single, '/api/${sample.$1}/z_new/zero-review');
      expect(
        fake.mutationBodies.single,
        contains('"expectedFinancialVersion":2'),
      );
      expect(fake.zeroReviewCommits, 1);
      final stored = (await tester.runAsync(
        () => fake.get('/api/${sample.$1}/z_new'),
      ))!;
      final card = stored.data as Map;
      expect(card['balanceUnits'], 0);
      expect(card['version'], 5);
      expect((card['zeroReview'] as Map)['financialVersion'], 2);
      expect((card['zeroReview'] as Map)['pending'], isFalse);
    });
  }

  testWidgets('a company writer reviews that section only', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1200));
    final fake = layer.client as FakeApiClient;
    fake.appendedAccountCards.add((
      section: 'companies',
      card: {
        'id': 'co_writer',
        'name': 'شركة الكاتب',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 1,
        'zeroReview': {
          'pending': true,
          'financialVersion': 0,
          'reviewedAt': null,
          'reviewedByName': null,
        },
      },
    ));
    await signIn(tester, username: 'company.writer', password: 'demo-only');
    await go(tester, '/companies');
    expect(find.byKey(const ValueKey('zero-review-co_writer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zero-review-co_writer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pumpAndSettle();
    expect(fake.mutationPaths.single, '/api/companies/co_writer/zero-review');
    expect(fake.zeroReviewCommits, 1);
  });

  testWidgets('a failed list refresh keeps the server review on the card', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    fake.appendedAccountCards.add((
      section: 'companies',
      card: {
        'id': 'co_refresh',
        'name': 'تحديث فشل',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 2,
        'zeroReview': {
          'pending': true,
          'financialVersion': 4,
          'reviewedAt': null,
          'reviewedByName': null,
        },
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    fake.failAccountListRemaining = 1;
    await tester.tap(find.byKey(const ValueKey('zero-review-co_refresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحديث القائمة.'), findsOneWidget);
    expect(find.byKey(const ValueKey('zero-review-co_refresh')), findsNothing);
    expect(fake.zeroReviewCommits, 1);
    final stored = (await tester.runAsync(
      () => fake.get('/api/companies/co_refresh'),
    ))!;
    expect(((stored.data as Map)['zeroReview'] as Map)['pending'], isFalse);
  });

  testWidgets('a 409 leaves the card pending and unmoved', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    fake.appendedAccountCards.add((
      section: 'libyan-deposits',
      card: {
        'id': 'ly_stale',
        'name': 'نسخة قديمة',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 2,
        'zeroReview': {
          'pending': true,
          'financialVersion': 1,
          'reviewedAt': null,
          'reviewedByName': null,
        },
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/libyan-deposits');
    fake.failNextResponse = (
      status: 409,
      code: 'ZERO_REVIEW_CHANGED',
      message: 'تغيّر الكارت بعد عرضه. راجع آخر حركة قبل تأكيد المراجعة.',
    );
    await tester.tap(find.byKey(const ValueKey('zero-review-ly_stale')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zero-preview-error')), findsOneWidget);
    expect(find.textContaining('تغيّر الكارت بعد عرضه'), findsOneWidget);
    expect(find.byKey(const ValueKey('zero-review-ly_stale')), findsOneWidget);
    expect(fake.zeroReviewCommits, 0);
  });

  testWidgets('logout during the review does not keep the response', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1200));
    final fake = layer.client as FakeApiClient;
    fake.appendedAccountCards.add((
      section: 'companies',
      card: {
        'id': 'co_race',
        'name': 'أثناء الخروج',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 1,
        'zeroReview': {
          'pending': true,
          'financialVersion': 1,
          'reviewedAt': null,
          'reviewedByName': null,
        },
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    final gate = Completer<void>();
    fake.pauseMutations = gate;
    await tester.tap(find.byKey(const ValueKey('zero-review-co_race')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.mutationPaths, ['/api/companies/co_race/zero-review']);
    fake.expireSession();
    gate.complete();
    fake.pauseMutations = null;
    await tester.pumpAndSettle();
    expect(fake.zeroReviewCommits, 0);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    expect(find.byKey(const ValueKey('zero-review-co_race')), findsOneWidget);
  });

  testWidgets('section zero review holds at 360 and text scale 2', (
    tester,
  ) async {
    await tester.runAsync(loadScreenshotFonts);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      textScale: 2,
    );
    (layer.client as FakeApiClient).appendedAccountCards.add((
      section: 'companies',
      card: {
        'id': 'co_narrow',
        'name': 'شركة ضيقة',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 1,
        'zeroReview': {
          'pending': true,
          'financialVersion': 1,
          'reviewedAt': null,
          'reviewedByName': null,
        },
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('zero-review-co_narrow')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('screen-companies')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await saveShot(tester, 'section-zero-light-360');
    expect(tester.takeException(), isNull);
    await go(tester, '/settings');
    await tester.tap(find.byKey(const Key('settings-theme-switch')));
    await tester.pumpAndSettle();
    await go(tester, '/companies');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('zero-review-co_narrow')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('screen-companies')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await saveShot(tester, 'section-zero-dark-360');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

bool _before(WidgetTester tester, String first, String second) {
  final a = tester.getRect(find.byKey(Key('account-card-$first')));
  final b = tester.getRect(find.byKey(Key('account-card-$second')));
  if ((a.top - b.top).abs() > 8) return a.top < b.top;
  return a.center.dx > b.center.dx;
}
