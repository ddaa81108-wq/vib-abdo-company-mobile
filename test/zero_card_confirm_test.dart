import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_logic.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  test('closed zero reviews sink without moving the other cards', () {
    final cards = [
      _card('a', 'أول', 320, null),
      _card('z', 'صفر', 0, const {'pending': false}),
      _card('b', 'ثان', 10, const {'status': 'pending'}),
      _card('c', 'مغلق', 0, const {'status': 'confirmed'}),
    ];
    expect(customersWithClosedZeroReviewLast(cards).map((card) => card.id), [
      'a',
      'b',
      'z',
      'c',
    ]);
  });

  testWidgets(
    'a zero card confirms then sits at the bottom, and a failure stays put',
    (tester) async {
      final layer = await pumpFakeApp(
        tester,
        size: const Size(440, 956),
        textScale: 1.3,
      );
      final fake = layer.client as FakeApiClient;
      fake.appendedAccountCards.add((
        section: 'customers',
        card: {
          'id': 'c_zero',
          'name': 'عميل صفر',
          'balanceUnits': 0,
          'currency': 'LYD',
          'version': 4,
          'ageStatus': 'zero',
          'zeroReview': {
            'status': 'pending',
            'pending': true,
            'financialVersion': 4,
          },
        },
      ));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers');
      expect(tester.takeException(), isNull);
      expect(_before(tester, 'c_zero', 'c_55'), isTrue);

      fake.failNextResponse = (
        status: 400,
        code: 'ZERO_REVIEW_REJECTED',
        message: 'لا يمكن اعتماد هذا الكارت الصفري الآن لأن المراجعة المالية لم تكتمل على الخادم ويجب إعادة المحاولة بعد التحديث',
      );
      await tester.tap(find.byKey(const ValueKey('zero-review-c_zero')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('zero-preview')), findsOneWidget);
      expect(
        fake.mutationPaths.where((path) => path.endsWith('/zero-review')),
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('zero-preview-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('zero-preview')), findsNothing);
      expect(
        fake.mutationPaths.where((path) => path.endsWith('/zero-review')),
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('zero-review-c_zero')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('zero-preview-confirm')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('zero-preview-error')), findsOneWidget);
      expect(
        find.textContaining('لا يمكن اعتماد هذا الكارت الصفري'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('zero-review-c_zero')), findsOneWidget);
      expect(_before(tester, 'c_zero', 'c_55'), isTrue);
      expect(
        fake.mutationPaths.where((path) => path.endsWith('/zero-review')),
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('zero-preview-confirm')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('zero-review-c_zero')), findsNothing);
      expect(_before(tester, 'c_55', 'c_zero'), isTrue);
      expect(
        fake.mutationPaths.where((path) => path.endsWith('/zero-review')),
        hasLength(1),
      );
    },
  );

  testWidgets('the review sends financialVersion, not the card version', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 900));
    final fake = layer.client as FakeApiClient;
    fake.appendedAccountCards.add((
      section: 'customers',
      card: {
        'id': 'c_fin',
        'name': 'إصدار مختلف',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 4,
        'zeroReview': {
          'pending': true,
          'financialVersion': 9,
        },
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.tap(find.byKey(const ValueKey('zero-review-c_fin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zero-preview')), findsOneWidget);
    expect(fake.mutationBodies, isEmpty);
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pumpAndSettle();
    final body = fake.mutationBodies.join('\n');
    expect(body, contains('"expectedFinancialVersion":9'));
    expect(body, isNot(contains('"expectedFinancialVersion":4')));
    expect(find.byKey(const ValueKey('zero-review-c_fin')), findsNothing);
  });

  testWidgets('a changed financial version is not posted from the preview', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 900));
    final fake = layer.client as FakeApiClient;
    final card = <String, dynamic>{
      'id': 'c_stale',
      'name': 'إصدار تغيّر',
      'balanceUnits': 0,
      'currency': 'LYD',
      'version': 4,
      'zeroReview': {'pending': true, 'financialVersion': 3},
    };
    fake.appendedAccountCards.add((section: 'customers', card: card));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.tap(find.byKey(const ValueKey('zero-review-c_stale')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zero-preview')), findsOneWidget);
    card['zeroReview'] = {'pending': true, 'financialVersion': 8};
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('zero-preview'))),
    ).invalidate(accountsProvider(AccountSection.customers));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('تغيرت بيانات الكارت. أعد فتح المعاينة.'), findsOneWidget);
    expect(fake.mutationBodies, isEmpty);
    expect(find.byKey(const Key('zero-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('zero-review-c_stale')), findsOneWidget);
  });

  testWidgets('a missing financial version never sends the review', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 900));
    (layer.client as FakeApiClient).appendedAccountCards.add((
      section: 'customers',
      card: {
        'id': 'c_missing',
        'name': 'بدون إصدار',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 4,
        'zeroReview': {'pending': true},
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await tester.tap(find.byKey(const ValueKey('zero-review-c_missing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zero-preview')), findsOneWidget);
    expect(
      find.text('لا يوجد إصدار مالي. لا يمكن إرسال المراجعة.'),
      findsOneWidget,
    );
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('zero-preview-confirm')),
    );
    expect(confirm.onPressed, isNull);
    await tester.tap(find.byKey(const Key('zero-preview-cancel')));
    await tester.pumpAndSettle();
    expect(
      (layer.client as FakeApiClient).mutationPaths.where(
        (path) => path.contains('zero-review'),
      ),
      isEmpty,
    );
  });

  testWidgets('companies do not pretend to review a zero card', (tester) async {
    await pumpFakeApp(tester, size: const Size(440, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    expect(find.byKey(const Key('zero-review-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('zero-review-co_1')), findsNothing);
  });

  testWidgets('an employee does not get the zero-review check', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 956));
    (layer.client as FakeApiClient).appendedAccountCards.add((
      section: 'customers',
      card: {
        'id': 'c_zero',
        'name': 'عميل صفر',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 4,
        'zeroReview': {'status': 'pending', 'pending': true},
      },
    ));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/customers');
    expect(find.byKey(const ValueKey('zero-review-c_zero')), findsNothing);
    expect(
      (layer.client as FakeApiClient).mutationPaths.where(
        (path) => path.contains('zero-review'),
      ),
      isEmpty,
    );
  });

  testWidgets('offline does not confirm or move the zero card', (tester) async {
    final link = ToggleConnectivity(true);
    final layer = await pumpFakeApp(
      tester,
      size: const Size(440, 956),
      connectivity: link,
    );
    (layer.client as FakeApiClient).appendedAccountCards.add((
      section: 'customers',
      card: {
        'id': 'c_zero',
        'name': 'عميل صفر',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 4,
        'zeroReview': {'status': 'pending', 'pending': true},
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('zero-review-c_zero')),
    );
    expect(button.onPressed, isNull);
    expect(_before(tester, 'c_zero', 'c_55'), isTrue);
  });

  testWidgets('zero card before and after confirm, fake 440', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 956));
    await tester.runAsync(loadScreenshotFonts);
    (layer.client as FakeApiClient).appendedAccountCards.add((
      section: 'customers',
      card: {
        'id': 'c_zero',
        'name': 'عميل صفر',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 4,
        'ageStatus': 'zero',
        'zeroReview': {
          'status': 'pending',
          'pending': true,
          'financialVersion': 4,
        },
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    await saveShot(tester, 'zero-card-before-confirm');
    await tester.tap(find.byKey(const ValueKey('zero-review-c_zero')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zero-preview')), findsOneWidget);
    await saveShot(tester, 'zero-preview');
    await tester.tap(find.byKey(const Key('zero-preview-confirm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('account-card-c_zero')),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('screen-customers')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pump();
    await saveShot(tester, 'zero-card-after-confirm');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

/// Reading order: upper rows first, and on one row the physical right first.
bool _before(WidgetTester tester, String first, String second) {
  final a = tester.getRect(find.byKey(Key('account-card-$first')));
  final b = tester.getRect(find.byKey(Key('account-card-$second')));
  if ((a.top - b.top).abs() > 8) return a.top < b.top;
  return a.center.dx > b.center.dx;
}

AccountCardDto _card(
  String id,
  String name,
  int balance,
  Map<String, dynamic>? review,
) {
  return AccountCardDto(
    id: id,
    name: name,
    balanceUnits: MoneyValue.known(balance),
    currency: Currency.lyd,
    version: 4,
    zeroReview: review,
  );
}
