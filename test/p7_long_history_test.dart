import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/performance/history_window.dart';

import 'support/pump_app.dart';

/// P7-25. Widget level. The rows come from [FakeApiClient] through the
/// repository. The load-more control is the ledger's real `load-older` button.
///
/// The 8 second bound is an engineering proposal for this widget test. It is
/// not an acceptance threshold. Ali sets those.
void main() {
  tearDown(() {
    HistoryWindow.trimEnabled = HistoryWindow.trimEnabledFromEnvironment;
  });

  testWidgets('P7-25 HISTORY_WINDOW_TRIM off keeps every loaded ledger row', (
    tester,
  ) async {
    HistoryWindow.trimEnabled = false;
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(800, 1400),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    final clock = Stopwatch()..start();
    GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
        .go('/customers/${FakeLargeCatalog.longLedgerAccountId}');
    await _until(tester, const Key('load-older'));

    var taps = 0;
    while (find.byKey(const Key('load-older')).evaluate().isNotEmpty) {
      taps++;
      expect(taps, lessThanOrEqualTo(FakeLargeCatalog.ledgerPageCount));
      await _pressLoadOlder(tester);
    }
    clock.stop();

    expect(taps, FakeLargeCatalog.ledgerPageCount - 1);
    expect(find.byKey(const Key('ledger-pages-20')), findsOneWidget);
    final olderRows =
        (FakeLargeCatalog.ledgerPageCount - 1) * FakeLargeCatalog.pageSize;
    expect(find.byKey(Key('ledger-retained-$olderRows')), findsOneWidget);
    final built = _keyedPrefix(tester, 'ledger-sequence-');
    expect(built, greaterThan(0));
    expect(built, lessThan(FakeLargeCatalog.pageSize));
    expect(
      clock.elapsed,
      lessThan(const Duration(seconds: 8)),
      reason:
          'Engineering proposal: this widget walk stays under 8s. '
          'Not an acceptance threshold. Ali sets acceptance.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'P7-25 HISTORY_WINDOW_TRIM on keeps 80 ledger rows and walks to the last page',
    (tester) async {
      HistoryWindow.trimEnabled = true;
      await pumpFakeApp(
        tester,
        fakeDataset: FakeDataset.large,
        size: const Size(800, 1400),
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
          .go('/customers/${FakeLargeCatalog.longLedgerAccountId}');
      await _until(tester, const Key('load-older'));
      var taps = 0;
      while (find.byKey(const Key('load-older')).evaluate().isNotEmpty) {
        taps++;
        expect(taps, lessThanOrEqualTo(FakeLargeCatalog.ledgerPageCount));
        await _pressLoadOlder(tester);
      }
      expect(taps, FakeLargeCatalog.ledgerPageCount - 1);
      expect(find.byKey(const Key('ledger-pages-20')), findsOneWidget);
      expect(
        find.byKey(Key('ledger-retained-${HistoryWindow.retainLimit}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('P7-24 P7-25 customer and notification lists stay lazy', (
    tester,
  ) async {
    HistoryWindow.trimEnabled = false;
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(800, 1400),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final router = GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)));

    router.go('/customers');
    await _until(tester, const Key('account-cards-list'));
    final cards = _keyedPrefix(tester, 'account-card-');
    expect(cards, greaterThan(0));
    expect(cards, lessThan(FakeLargeCatalog.pageSize));

    router.go('/notifications');
    await _until(tester, const Key('notifications-list'));
    expect(find.byKey(const Key('load-older-notifications')), findsNothing);
    expect(
      find.byKey(Key('notifications-retained-${FakeLargeCatalog.pageSize}')),
      findsOneWidget,
    );
    final notices = _keyedPrefix(tester, 'notice-');
    expect(notices, greaterThan(0));
    expect(notices, lessThan(FakeLargeCatalog.pageSize));
    expect(tester.takeException(), isNull);
  });

  testWidgets('P7-25 HISTORY_WINDOW_TRIM on caps notifications at 120', (
    tester,
  ) async {
    HistoryWindow.trimEnabled = true;
    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(800, 1400),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
        .go('/notifications');
    await _until(tester, const Key('load-older-notifications'));
    var taps = 0;
    while (find
        .byKey(const Key('load-older-notifications'))
        .evaluate()
        .isNotEmpty) {
      taps++;
      expect(taps, lessThan(8));
      final finder = find.byKey(const Key('load-older-notifications'));
      await tester.ensureVisible(finder);
      tester.widget<TextButton>(finder).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      for (var i = 0; i < 20; i++) {
        if (finder.evaluate().isEmpty) break;
        if (tester.widget<TextButton>(finder).onPressed != null) break;
        await tester.pump(const Duration(milliseconds: 20));
      }
    }
    expect(
      find.byKey(
        Key('notifications-retained-${HistoryWindow.notificationRetain}'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

int _keyedPrefix(WidgetTester tester, String prefix) {
  return find
      .byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith(prefix);
      })
      .evaluate()
      .length;
}

Future<void> _until(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('missing $key');
}

/// The wide shell rail covers the button's center, so a coordinate tap misses.
/// This calls the same [TextButton.onPressed] the control shows.
Future<void> _pressLoadOlder(WidgetTester tester) async {
  final finder = find.byKey(const Key('load-older'));
  await tester.ensureVisible(finder);
  final button = tester.widget<TextButton>(finder);
  expect(button.onPressed, isNotNull);
  button.onPressed!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  for (var i = 0; i < 20; i++) {
    if (finder.evaluate().isEmpty) return;
    final current = tester.widget<TextButton>(finder);
    if (current.onPressed != null) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
}
