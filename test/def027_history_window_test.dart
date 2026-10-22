import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/performance/history_window.dart';

import 'support/pump_app.dart';

/// DEF-027. Real screens, [FakeDataset.large].
///
/// The newest rows stay on screen as one contiguous block. Trimming drops the
/// oldest rows. Those rows come back from load-older or from scrolling the
/// list to its end. Pull-to-refresh starts the window over.
void main() {
  tearDown(() {
    HistoryWindow.trimEnabled = HistoryWindow.trimEnabledFromEnvironment;
  });

  testWidgets('DEF-027 ledger keeps the newest rows and reloads the oldest', (
    tester,
  ) async {
    HistoryWindow.trimEnabled = true;
    await _openLarge(tester);
    _go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    await _until(tester, const Key('load-older'));

    await _press(tester, const Key('load-older'), times: 3);
    expect(
      find.byKey(Key('ledger-retained-${HistoryWindow.retainLimit}')),
      findsOneWidget,
    );
    final trimmed = _ledgerIds();
    _expectNewestPrefix(trimmed, length: 120, dropped: 120);
    expect(find.byKey(const Key('ledger-sequence-ltx_00000')), findsOneWidget);

    await _press(tester, const Key('load-older'));
    final reloaded = _ledgerIds();
    _expectNewestPrefix(reloaded, length: 160, dropped: 160);
    expect(_indexes(reloaded), contains(120));
    expect(find.byKey(const Key('ledger-sequence-ltx_00000')), findsOneWidget);

    await _refresh(tester, const Key('ledger-refresh'));
    await _until(tester, const Key('ledger-retained-0'));
    expect(find.byKey(const Key('load-older')), findsOneWidget);
    final reset = _ledgerIds();
    _expectNewestPrefix(reset, length: FakeLargeCatalog.pageSize, dropped: 40);
    expect(find.byKey(const Key('ledger-sequence-ltx_00000')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DEF-027 scrolling the ledger reaches the dropped older rows', (
    tester,
  ) async {
    HistoryWindow.trimEnabled = true;
    await _openLarge(tester);
    _go(tester, '/customers/${FakeLargeCatalog.longLedgerAccountId}');
    await _until(tester, const Key('load-older'));
    await _press(tester, const Key('load-older'), times: 3);
    expect(
      find.byKey(Key('ledger-retained-${HistoryWindow.retainLimit}')),
      findsOneWidget,
    );

    await _scrollToEnd(tester, const Key('ledger-older-list'));
    final reached = _ledgerIds();
    expect(_indexes(reached), contains(0));
    expect(_indexes(reached), contains(120));
    _expectNoGaps(reached);
    expect(find.byKey(const Key('ledger-sequence-ltx_00000')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DEF-027 accounts keep a newest prefix and refresh resets it', (
    tester,
  ) async {
    HistoryWindow.trimEnabled = true;
    await _openLarge(tester);
    _go(tester, '/customers');
    await _until(tester, const Key('load-more-accounts'));

    await _press(tester, const Key('load-more-accounts'), times: 3);
    final trimmed = HistoryWindowTrace.accountWindow;
    _expectNewestPrefix(trimmed, length: 120, dropped: 120);
    expect(_indexes(trimmed), contains(50));
    expect(find.byKey(const Key('account-card-lc_00000')), findsOneWidget);

    await _press(tester, const Key('load-more-accounts'));
    final reloaded = HistoryWindowTrace.accountWindow;
    _expectNewestPrefix(reloaded, length: 160, dropped: 160);
    expect(_indexes(reloaded), contains(50));
    expect(_indexes(reloaded), contains(120));

    await _refresh(tester, const Key('accounts-refresh'));
    await _until(tester, const Key('load-more-accounts'));
    final reset = HistoryWindowTrace.accountWindow;
    _expectNewestPrefix(reset, length: FakeLargeCatalog.pageSize, dropped: 50);
    expect(find.byKey(const Key('account-card-lc_00000')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DEF-027 notifications keep the newest rows and refresh starts over',
    (tester) async {
      HistoryWindow.trimEnabled = true;
      await _openLarge(tester);
      _go(tester, '/notifications');
      await _until(tester, const Key('load-older-notifications'));

      await _press(tester, const Key('load-older-notifications'), times: 3);
      expect(
        find.byKey(
          Key('notifications-retained-${HistoryWindow.notificationRetain}'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('load-older-notifications')), findsOneWidget);
      final trimmed = HistoryWindowTrace.notificationWindow;
      _expectNewestPrefix(trimmed, length: 120, dropped: 120);
      expect(find.byKey(const Key('notice-ln_u_1_00000')), findsOneWidget);

      await _press(tester, const Key('load-older-notifications'));
      final reloaded = HistoryWindowTrace.notificationWindow;
      _expectNewestPrefix(reloaded, length: 160, dropped: 160);
      expect(_indexes(reloaded), contains(120));
      expect(find.byKey(const Key('notice-ln_u_1_00000')), findsOneWidget);
      expect(find.byKey(const Key('load-older-notifications')), findsOneWidget);

      await _refresh(tester, const Key('notifications-refresh'));
      await _until(
        tester,
        Key('notifications-retained-${FakeLargeCatalog.pageSize}'),
      );
      expect(find.byKey(const Key('load-older-notifications')), findsOneWidget);
      final reset = HistoryWindowTrace.notificationWindow;
      _expectNewestPrefix(
        reset,
        length: FakeLargeCatalog.pageSize,
        dropped: 120,
      );
      expect(find.byKey(const Key('notice-ln_u_1_00000')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openLarge(WidgetTester tester) async {
  await pumpFakeApp(
    tester,
    fakeDataset: FakeDataset.large,
    size: const Size(800, 1400),
  );
  await signIn(tester, username: 'admin.demo', password: 'demo-only');
}

void _go(WidgetTester tester, String location) {
  GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(location);
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
///
/// Fake latency is zero, which is still a timer. A positive [pump] has to run
/// before the next press, or the in-flight page is dropped.
Future<void> _press(WidgetTester tester, Key key, {int times = 1}) async {
  for (var tap = 0; tap < times; tap++) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    final button = tester.widget<TextButton>(finder);
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }
}

/// Advance the test clock before waiting on the refresh future. A zero-length
/// pump does not fire the fake client's timer, so awaiting first never returns.
Future<void> _refresh(WidgetTester tester, Key key) async {
  final indicator = tester.widget<RefreshIndicator>(find.byKey(key));
  final pending = indicator.onRefresh();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await pending;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _scrollToEnd(WidgetTester tester, Key listKey) async {
  final list = find.byKey(listKey);
  expect(list, findsOneWidget);
  final gesture = await tester.startGesture(tester.getCenter(list));
  for (var step = 0; step < 30; step++) {
    await gesture.moveBy(const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 16));
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)),
        )
        .position;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 24) {
      break;
    }
  }
  await gesture.up();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

List<String> _ledgerIds() {
  return [...HistoryWindowTrace.ledgerPage, ...HistoryWindowTrace.ledgerExtra];
}

Set<int> _indexes(Iterable<String> ids) {
  return ids.map((id) {
    final match = RegExp(r'(\d+)$').firstMatch(id);
    expect(match, isNotNull, reason: id);
    return int.parse(match!.group(1)!);
  }).toSet();
}

void _expectNoGaps(Iterable<String> ids) {
  final indexes = _indexes(ids);
  expect(indexes, isNotEmpty);
  final max = indexes.reduce((a, b) => a > b ? a : b);
  for (var i = 0; i <= max; i++) {
    expect(indexes, contains(i), reason: 'gap at $i');
  }
}

void _expectNewestPrefix(
  Iterable<String> ids, {
  required int length,
  required int dropped,
}) {
  final indexes = _indexes(ids);
  expect(indexes, contains(0), reason: 'newest row missing');
  expect(indexes, isNot(contains(dropped)), reason: 'dropped row still shown');
  expect(indexes, hasLength(length));
  for (var i = 0; i < length; i++) {
    expect(indexes, contains(i), reason: 'gap at $i');
  }
}
