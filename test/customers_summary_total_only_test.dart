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
    expect(find.text(AppStrings.activeCardsCount), findsNothing);
    expect(find.text(AppStrings.netDebt), findsNothing);
    expect(find.text(AppStrings.totalDebt), findsNothing);
    // Amount on the right (RTL start), add on the other side of the divider.
    final box = tester.getRect(card);
    final amount = tester.getRect(
      find.byKey(const Key('customers-summary-amount')),
    );
    final add = tester.getRect(find.byKey(const Key('add-account')));
    expect(box.right - amount.right, lessThan(amount.left - box.left));
    expect(add.center.dx, lessThan(amount.center.dx));
    expect((add.center.dy - box.center.dy).abs(), lessThan(8));
    // «النشطة», search, and «توجيه» share one row. No other filter words.
    expect(find.byKey(const ValueKey('account-filter-all')), findsNothing);
    expect(find.text(AppStrings.todayTab), findsNothing);
    final active = tester.getCenter(
      find.byKey(const Key('debt-active-filter')),
    );
    final search = tester.getCenter(find.byKey(const Key('account-search')));
    final assign = tester.getCenter(find.byKey(const Key('assign-mode')));
    expect(active.dx, greaterThan(search.dx));
    expect(search.dx, greaterThan(assign.dx));
    expect((active.dy - assign.dy).abs(), lessThan(4));
    // One card per row. Height follows the text, and the pin is on the card.
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('account-card-'),
    );
    final rects = [
      for (final e in cards.evaluate()) tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects.length, greaterThan(2));
    expect(rects.every((r) => r.height > 80), isTrue);
    expect(rects[1].top, greaterThan(rects[0].bottom - 1));
    expect(find.byKey(const Key('pin-c_55')), findsOneWidget);
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
    expect(find.text(AppStrings.companiesActiveCards), findsNothing);
    expect(find.text(AppStrings.customersTotalDebt), findsNothing);
    expect(find.byKey(const ValueKey('account-filter-all')), findsNothing);
    expect(find.byKey(const Key('companies-toolbar')), findsOneWidget);
    final active = tester.getCenter(
      find.byKey(const Key('debt-active-filter')),
    );
    final search = tester.getCenter(find.byKey(const Key('account-search')));
    final assign = tester.getCenter(find.byKey(const Key('assign-mode')));
    expect(active.dx, greaterThan(search.dx));
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
    expect(rects.every((r) => r.height > 80), isTrue);
    expect(rects[1].top, greaterThan(rects[0].bottom - 1));
    // No customers-only ✓ zero review on a company card.
    expect(find.byKey(const ValueKey('zero-review-c_co_04')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
