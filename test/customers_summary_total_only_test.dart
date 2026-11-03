import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('customers screen: summary, toolbar, compact cards', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    final card = find.byKey(const Key('customers-summary'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text(AppStrings.customersTotalDebt),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(AppStrings.activeCardsCount),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.netDebt), findsNothing);
    expect(find.text(AppStrings.totalDebt), findsNothing);
    // Amount on the right (RTL start), count on the left.
    final box = tester.getRect(card);
    final amount = tester.getRect(
      find.byKey(const Key('customers-summary-amount')),
    );
    final count = tester.getRect(
      find.byKey(const Key('customers-summary-count')),
    );
    expect(box.right - amount.right, lessThan(amount.left - box.left));
    expect(count.left - box.left, lessThan(box.right - count.right));
    // No filter chips; add right, search middle, assign left.
    expect(find.byKey(const ValueKey('account-filter-all')), findsNothing);
    final add = tester.getCenter(find.byKey(const Key('add-account')));
    final search = tester.getCenter(find.byKey(const Key('account-search')));
    final assign = tester.getCenter(find.byKey(const Key('assign-mode')));
    expect(add.dx, greaterThan(search.dx));
    expect(search.dx, greaterThan(assign.dx));
    expect((add.dy - assign.dy).abs(), lessThan(4));
    // Cards: one height, two per row, no pin or age.
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('account-card-'),
    );
    final rects = [
      for (final e in cards.evaluate()) tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects.length, greaterThan(2));
    expect(rects.map((r) => r.height.round()).toSet(), hasLength(1));
    expect(rects[0].top, rects[1].top);
    expect(find.byKey(const Key('pin-c_55')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('companies: same design, their own summary and labels', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies');
    expect(find.byKey(const Key('customers-summary')), findsNothing);
    final card = find.byKey(const Key('companies-summary'));
    expect(card, findsOneWidget);
    // Website labels for companies (DebtAccountsView).
    expect(
      find.descendant(of: card, matching: find.text(AppStrings.netDebt)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(AppStrings.companiesActiveCards),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.customersTotalDebt), findsNothing);
    expect(find.byKey(const ValueKey('account-filter-all')), findsNothing);
    expect(find.byKey(const Key('companies-toolbar')), findsOneWidget);
    final add = tester.getCenter(find.byKey(const Key('add-account')));
    final search = tester.getCenter(find.byKey(const Key('account-search')));
    final assign = tester.getCenter(find.byKey(const Key('assign-mode')));
    expect(add.dx, greaterThan(search.dx));
    expect(search.dx, greaterThan(assign.dx));
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('account-card-'),
    );
    final rects = [
      for (final e in cards.evaluate()) tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects.length, greaterThan(2));
    expect(rects.map((r) => r.height.round()).toSet(), hasLength(1));
    expect(rects[0].top, rects[1].top);
    // No customers-only ✓ zero review on a company card.
    expect(find.byKey(const ValueKey('zero-review-c_co_04')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
