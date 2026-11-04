import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

// Ali, 2026-11-04: سجل الفلوس النشطة as the website's grid.
void main() {
  for (final (size, scale) in const [
    (Size(430, 1400), 1.0),
    (Size(1280, 900), 1.0),
    (Size(430, 1800), 1.6),
  ]) {
    testWidgets('treasury total cards are equal and in Ali\'s order '
        '(${size.width.toInt()} x$scale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/treasury');
      await settle(tester);
      Rect card(String title) => tester.getRect(
        find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
      );
      final rects = [
        for (final t in const [
          AppStrings.receivables,
          AppStrings.liabilities,
          AppStrings.activeCash,
          AppStrings.egyptianTransfers,
        ])
          card(t),
      ];
      for (final r in rects) {
        expect(r.size, rects.first.size);
      }
      // RTL order: لنا before علينا, النشطة before المصرية; gold below all.
      if (rects[0].top == rects[1].top) {
        expect(rects[0].left, greaterThan(rects[1].left));
      }
      expect(rects[2].top, greaterThanOrEqualTo(rects[0].top));
      final net = card(AppStrings.netTreasury);
      for (final r in rects) {
        expect(net.top, greaterThan(r.top));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(430, 1400), Size(1280, 800)]) {
    testWidgets('treasury grid at ${size.width.toInt()}: header bar, pinned '
        'columns, oldest first, opening at the newest', (tester) async {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/treasury');
      await settle(tester);

      final grid = find.byKey(const Key('treasury-movements'));
      expect(grid, findsOneWidget);
      // Title pill and the دخول / خروج buttons sit in the header bar.
      for (final key in const ['cash-in', 'cash-out']) {
        expect(
          find.descendant(of: grid, matching: find.byKey(Key(key))),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: grid,
          matching: find.text(AppStrings.cashMovements),
        ),
        findsOneWidget,
      );
      final names = find.byKey(const Key('treasury-sticky-header'));
      for (final label in const [
        AppStrings.ledgerColSeq,
        AppStrings.cashColWhen,
        AppStrings.cashColMove,
        AppStrings.ledgerColValue,
        AppStrings.ledgerColNote,
        AppStrings.ledgerColBy,
        AppStrings.ledgerColBalance,
      ]) {
        expect(
          find.descendant(of: names, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      // ce_1 is the newest row: at the bottom, the list opens there.
      final rows = find.byKey(const Key('treasury-rows'));
      final newest = find.byKey(const Key('cash-entry-ce_1'));
      expect(newest, findsOneWidget);
      final list = tester.state<ScrollableState>(
        find.descendant(of: rows, matching: find.byType(Scrollable)).first,
      );
      expect(list.position.pixels, 0); // reverse list: 0 = newest at bottom
      // Older rows load above it (oldest first, top to bottom).
      final older = find.byKey(const Key('load-older'));
      expect(
        tester.getTopLeft(older).dy,
        lessThan(tester.getTopLeft(newest).dy),
      );
      await tester.tap(older);
      await settle(tester);
      final old = find.byKey(const Key('cash-entry-ce_old'));
      expect(old, findsOneWidget);
      expect(tester.getTopLeft(old).dy, lessThan(tester.getTopLeft(newest).dy));
      // The column names stay pinned while the rows scroll.
      final header = find.byKey(const Key('treasury-sticky-header'));
      final before = tester.getRect(header);
      list.position.jumpTo(list.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(header), before);
      // No total card under the grid; totals live in the top cards.
      expect(find.byKey(const Key('treasury-ledger-total')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
