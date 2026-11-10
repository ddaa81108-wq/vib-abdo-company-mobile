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

    await _scrollPageHome(tester);
    await saveShot(tester, 'purchases-grid-light-top');
    await _showLedger(tester);
    await _scrollLedgerHome(tester);
    _expectHeaderInView(tester, 'ت');
    _expectHeaderInView(tester, '2026-10-19');
    await saveShot(tester, 'purchases-grid-light-ledger');
    await _scrollLedgerEnd(tester);
    for (final header in const [
      'الناتج',
      'المسدد',
      'الباقي',
      'مستهلك فودافون',
      '✓',
    ]) {
      _expectHeaderInView(tester, header);
    }
    await saveShot(tester, 'purchases-grid-light-ledger-end');

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(HomeShell.shellKey)),
    );
    container.read(themeModeProvider.notifier).toggle();
    await _settle(tester);
    await _scrollPageHome(tester);
    await _scrollLedgerHome(tester);
    await saveShot(tester, 'purchases-grid-dark-top');
    await _showLedger(tester);
    await _scrollLedgerHome(tester);
    _expectHeaderInView(tester, 'ت');
    _expectHeaderInView(tester, '2026-10-19');
    await saveShot(tester, 'purchases-grid-dark-ledger');
    await _scrollLedgerEnd(tester);
    for (final header in const [
      'الناتج',
      'المسدد',
      'الباقي',
      'مستهلك فودافون',
      '✓',
    ]) {
      _expectHeaderInView(tester, header);
    }
    await saveShot(tester, 'purchases-grid-dark-ledger-end');
    expect(find.text(AppStrings.alBayan), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);

  testWidgets('inline ledger entry stays focused in the grid', (tester) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/purchases');
    await tester.tap(find.byKey(const Key('add-purchase-12')));
    await _settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    final value = find.descendant(
      of: find.byKey(const Key('purchase-field-value')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(value, '1500');
    await tester.pump();
    await _showLedger(tester);
    await saveShot(tester, 'purchases-grid-inline-focus-light');
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

ScrollableState _ledgerScroll(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byKey(const Key('purchase-ledger-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
}

Future<void> _scrollLedgerHome(WidgetTester tester) async {
  _ledgerScroll(tester).position.jumpTo(0);
  await tester.pump();
}

Future<void> _scrollLedgerEnd(WidgetTester tester) async {
  final position = _ledgerScroll(tester).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
}

Future<void> _scrollPageHome(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byKey(const Key('screen-purchases')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      ),
    ),
  );
  scrollable.position.jumpTo(0);
  await tester.pump();
}

void _expectHeaderInView(WidgetTester tester, String header) {
  final port = tester.getRect(find.byKey(const Key('purchase-ledger-scroll')));
  final text = find.text(header);
  expect(text, findsWidgets);
  Rect? visible;
  for (var i = 0; i < text.evaluate().length; i++) {
    final rect = tester.getRect(text.at(i));
    final overlaps = rect.right > port.left + 2 && rect.left < port.right - 2;
    if (overlaps && rect.width > 8) visible = rect;
  }
  expect(visible, isNotNull, reason: '$header is outside the ledger viewport');
  expect(visible!.left, greaterThanOrEqualTo(port.left - 2), reason: header);
  expect(visible.right, lessThanOrEqualTo(port.right + 2), reason: header);
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
