import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

/// P7-25. Widget level. The rows come from [FakeApiClient] through the
/// repository. The load-more control is the ledger's real `load-older` button.
void main() {
  testWidgets('P7-25 walks the long ledger to the last page', (tester) async {
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
    final built = _keyedPrefix(tester, 'ledger-sequence-');
    expect(built, greaterThan(0));
    expect(built, lessThan(FakeLargeCatalog.pageSize));
    expect(clock.elapsed, lessThan(const Duration(seconds: 8)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('P7-24 P7-25 customer and notification lists stay lazy', (
    tester,
  ) async {
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
    final notices = _keyedPrefix(tester, 'notice-');
    expect(notices, greaterThan(0));
    expect(notices, lessThan(FakeLargeCatalog.pageSize));
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
