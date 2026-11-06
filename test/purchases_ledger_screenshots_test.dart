import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'shell_screenshots_test.dart';
import 'support/pump_app.dart';

/// Logical viewport 440×956. Not a device capture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('purchases header and ledger, fake data, light and dark', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/purchases');

    await saveShot(tester, 'purchases-grid-light-top');
    await _showLedger(tester);
    await _scrollLedgerHome(tester);
    await saveShot(tester, 'purchases-grid-light-ledger');
    await _scrollLedger(tester, 400);
    await saveShot(tester, 'purchases-grid-light-ledger-mid');
    await _scrollLedger(tester, 280);
    await saveShot(tester, 'purchases-grid-light-ledger-end');

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(HomeShell.shellKey)),
    );
    container.read(themeModeProvider.notifier).toggle();
    await _settle(tester);
    await _scrollLedgerHome(tester);
    await tester.drag(
      find.byKey(const Key('screen-purchases')),
      const Offset(0, 800),
    );
    await tester.pump();
    await saveShot(tester, 'purchases-grid-dark-top');
    await _showLedger(tester);
    await _scrollLedgerHome(tester);
    await saveShot(tester, 'purchases-grid-dark-ledger');
    await _scrollLedger(tester, 400);
    await saveShot(tester, 'purchases-grid-dark-ledger-mid');
    await _scrollLedger(tester, 280);
    await saveShot(tester, 'purchases-grid-dark-ledger-end');
    expect(find.text(AppStrings.alBayan), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

Future<void> _showLedger(WidgetTester tester) async {
  final list = find.byKey(const Key('screen-purchases'));
  final ledger = find.byKey(const Key('purchase-ledger'));
  for (var i = 0; i < 8; i++) {
    final rect = tester.getRect(ledger);
    if (rect.top > 96 && rect.top < 280) break;
    await tester.drag(list, Offset(0, rect.top > 280 ? -220 : 180));
    await tester.pump();
  }
}

Future<void> _scrollLedger(WidgetTester tester, double dx) async {
  await tester.drag(
    find.byKey(const Key('purchase-ledger-scroll')),
    Offset(dx, 0),
  );
  await tester.pump();
}

Future<void> _scrollLedgerHome(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byKey(const Key('purchase-ledger-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  scrollable.position.jumpTo(0);
  await tester.pump();
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
