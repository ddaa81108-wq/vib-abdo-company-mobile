import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_logic.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  test('closed zero reviews sink without moving the other cards', () {
    final cards = [
      _card('a', 'أول', 320, null),
      _card('z', 'صفر', 0, const {'pending': false}),
      _card('n', 'صار دينًا', 40, const {'pending': false}),
      _card('b', 'ثان', 10, const {'status': 'pending'}),
      _card('c', 'مغلق', 0, const {'status': 'confirmed'}),
      _card('z', 'مكرر', 0, const {'pending': false}),
    ];
    expect(customersWithClosedZeroReviewLast(cards).map((card) => card.id), [
      'a',
      'n',
      'b',
      'z',
      'c',
    ]);
  });

  for (final failure in [false, true]) {
    testWidgets(
      'direct customer review handles rejection and retry: $failure',
      (tester) async {
        final layer = await pumpFakeApp(tester, size: const Size(440, 1100));
        final fake = layer.client as FakeApiClient;
        fake.appendedAccountCards.add((
          section: 'customers',
          card: {
            'id': 'c_direct',
            'name': 'عميل مراجعة',
            'balanceUnits': 0,
            'currency': 'LYD',
            'version': 4,
            'zeroReview': {'pending': true, 'financialVersion': 9},
          },
        ));
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/customers');
        if (failure) {
          fake.failNextResponse = (
            status: 409,
            code: 'ZERO_REVIEW_CHANGED',
            message: 'تغيرت بيانات الكارت على الخادم',
          );
        }
        await tester.tap(find.byKey(const ValueKey('zero-review-c_direct')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        if (failure) {
          expect(fake.zeroReviewCommits, 0);
          expect(
            find.textContaining('تغيرت بيانات الكارت على الخادم'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('zero-review-c_direct')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('zero-review-c_direct')));
          await tester.pumpAndSettle();
        }
        expect(fake.zeroReviewCommits, 1);
        expect(
          fake.mutationBodies.join(),
          contains('"expectedFinancialVersion":9'),
        );
        expect(
          find.byKey(const ValueKey('zero-review-c_direct')),
          findsNothing,
        );
        expect(find.byKey(const Key('account-card-c_direct')), findsOneWidget);
      },
    );
  }
  testWidgets('missing financial version does not send a direct review', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1100));
    final fake = layer.client as FakeApiClient;
    fake.appendedAccountCards.add((
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
    expect(fake.zeroReviewCommits, 0);
    expect(find.textContaining('لا يوجد إصدار مالي'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('a company card without zeroReview does not offer a check', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 900));
    (layer.client as FakeApiClient).appendedAccountCards.add((
      section: 'companies',
      card: {
        'id': 'co_old',
        'name': 'شركة بلا حقل',
        'balanceUnits': 0,
        'currency': 'LYD',
        'version': 2,
      },
    ));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    expect(find.byKey(const Key('zero-review-unavailable')), findsNothing);
    expect(find.byKey(const ValueKey('zero-review-co_old')), findsNothing);
    expect(
      (layer.client as FakeApiClient).mutationPaths.where(
        (path) => path.contains('zero-review'),
      ),
      isEmpty,
    );
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
    await tester.tap(find.byKey(const ValueKey('zero-review-c_zero')));
    await tester.pump();
    expect(find.byKey(const Key('screen-customers')), findsOneWidget);
    expect(_before(tester, 'c_zero', 'c_55'), isTrue);
  });
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
