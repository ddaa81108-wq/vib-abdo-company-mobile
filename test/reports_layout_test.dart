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
      // The 05:00 panel is the most prominent block (Ali, 2026-11-04).
      final five = find.byKey(const Key('report-five-am'));
      expect(five, findsOneWidget);
      if (size.width >= 900) {
        // Right half (RTL start); the hero sits on the left.
        expect(
          tester.getCenter(five).dx,
          greaterThan(
            tester.getCenter(find.byKey(const Key('report-current'))).dx,
          ),
        );
      } else {
        expect(top('report-current'), lessThan(top('report-five-am')));
        expect(top('report-five-am'), lessThan(top('report-balances')));
      }
      // Header row stays put while the snapshot rows scroll.
      final header = find.byKey(const Key('report-five-am-header'));
      final before = tester.getRect(header);
      await tester.drag(
        find.byKey(const Key('report-five-am-rows')),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(tester.getRect(header), before);
      expect(find.text(RText.net5), findsWidgets);
      // الفرق shown (display-only, Ali 2026-11-04) under «تفاصيل» header.
      expect(
        find.descendant(of: five, matching: find.text(RText.diff)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: five, matching: find.text(RText.detailsHead)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const Key('report-five-am-diff-29'),
            skipOffstage: false,
          ),
          matching: find.textContaining('+1,300', skipOffstage: false),
          matchRoot: true,
        ),
        findsOneWidget,
      );
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
    expect(block, findsOneWidget);
    // 13 recorded snapshots in the fake, newest first (seq 29).
    final open = find.byKey(const Key('report-open-29'));
    await tester.ensureVisible(open);
    await tester.pump();
    await tester.tap(open);
    await settle(tester);
    expect(find.byKey(const Key('report-day-sheet')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('snapshot-net')),
        matching: find.text('48,500 د.ل'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    expect(find.text('2026-10-18 05:00'), findsOneWidget);
    expect(find.byKey(const Key('snapshot-no-breakdown')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('snapshot-diff')),
        matching: find.textContaining('+1,300'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    expect(find.text(RText.diffDisplayOnly), findsOneWidget);
    // The sheet's last line clears the bottom tab bar.
    final last = tester.getRect(find.byKey(const Key('snapshot-no-breakdown')));
    final bar = find.byKey(const Key('bottom-tab-more'));
    if (bar.evaluate().isNotEmpty) {
      expect(last.bottom, lessThanOrEqualTo(tester.getRect(bar).top));
    }
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
