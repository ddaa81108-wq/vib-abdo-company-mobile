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

  // The ledger loads every older page by itself now, so row 1 is the
  // first movement and the running balance is complete (Ali, 2026-11-03).
  // The window trim no longer applies to the ledger; the list stays lazy.
  for (final trim in [false, true]) {
    testWidgets(
      'P7-25 the ledger walks every page by itself (trim ${trim ? 'on' : 'off'})',
      (tester) async {
        HistoryWindow.trimEnabled = trim;
        await pumpFakeApp(
          tester,
          fakeDataset: FakeDataset.large,
          size: const Size(800, 1400),
        );
        await signIn(tester, username: 'admin.demo', password: 'demo-only');

        HistoryWindowTrace.ledgerExtra = const [];
        final clock = Stopwatch()..start();
        GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)))
            .go('/customers/${FakeLargeCatalog.longLedgerAccountId}');
        await _untilAllPages(tester);
        clock.stop();

        expect(find.byKey(const Key('load-older')), findsNothing);
        final olderRows =
            (FakeLargeCatalog.ledgerPageCount - 1) * FakeLargeCatalog.pageSize;
        expect(HistoryWindowTrace.ledgerExtra, hasLength(olderRows));
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
      },
    );
  }

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

  testWidgets(
    'P7-25 HISTORY_WINDOW_TRIM on keeps the newest 120 notifications reachable',
    (tester) async {
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
      for (var taps = 0; taps < 3; taps++) {
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
      expect(find.byKey(const Key('load-older-notifications')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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

Future<void> _untilAllPages(WidgetTester tester) async {
  final loading = find.byKey(const Key('ledger-loading-older'));
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (HistoryWindowTrace.ledgerExtra.length ==
            (FakeLargeCatalog.ledgerPageCount - 1) *
                FakeLargeCatalog.pageSize &&
        loading.evaluate().isEmpty) {
      return;
    }
  }
  fail('the ledger did not finish loading its older pages');
}
