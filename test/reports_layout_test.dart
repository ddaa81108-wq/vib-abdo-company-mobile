import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/reports/report_blocks.dart';

import 'support/pump_app.dart';

// Ali, 2026-11-04: التقارير الذكية arranged like the website.
void main() {
  for (final (size, scale) in const [
    (Size(430, 2600), 1.0),
    (Size(1280, 1600), 1.0),
    (Size(390, 3600), 1.6),
  ]) {
    testWidgets('report blocks in order at ${size.width.toInt()} x$scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/reports');

      double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
      for (final key in const [
        'report-current',
        'report-balances',
        'report-sources',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(top('report-current'), lessThan(top('report-balances')));
      expect(top('report-balances'), lessThan(top('report-sources')));
      // Hero shows the server net as-is.
      expect(
        find.descendant(
          of: find.byKey(const Key('report-current')),
          matching: find.text('51,000 د.ل'),
        ),
        findsOneWidget,
      );
      // لنا / علينا cards are the same size.
      expect(
        tester.getSize(find.byKey(const Key('report-ours'))),
        tester.getSize(find.byKey(const Key('report-theirs'))),
      );
      // Source cards: equal sizes.
      final sources = find.byWidgetPredicate(
        (w) =>
            w is FigureCard &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('report-source-'),
      );
      expect(sources, findsWidgets);
      final first = tester.getSize(sources.first);
      for (final e in sources.evaluate()) {
        expect(e.size, first);
      }
      expect(find.text(RText.sources), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a source card opens its section', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');
    final card = find.byKey(const Key('report-source-customers'));
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await settle(tester);
    final router = GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/customers');
  });

  testWidgets('05:00 rows open the day details with an icon', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');
    final block = find.byKey(const Key('report-five-am'));
    if (block.evaluate().isEmpty) return; // no snapshots in this dataset
    final open = find.descendant(of: block, matching: find.byType(IconButton));
    await tester.ensureVisible(open.first);
    await tester.pump();
    await tester.tap(open.first);
    await settle(tester);
    expect(find.byKey(const Key('report-day-sheet')), findsOneWidget);
  });
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
