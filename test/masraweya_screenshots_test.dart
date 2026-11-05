import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'shell_screenshots_test.dart';
import 'support/pump_app.dart';

/// Logical viewport 440×956 (large-phone portrait). Not a Samsung device.
/// Headless flutter_tester, device pixel ratio 1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('masraweya viewport shots, fake data, light and dark', (
    tester,
  ) async {
    const viewport = Size(440, 956);
    await pumpFakeApp(tester, size: viewport);
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/masraweya');
    await saveShot(tester, 'masraweya-gold-light-top');
    await tester.ensureVisible(find.byKey(const Key('masraweya-summary')));
    await tester.pump();
    await saveShot(tester, 'masraweya-gold-light-summary');
    await saveBoundaryShot(
      tester,
      find.byKey(const Key('masraweya-summary-capture')),
      'masraweya-gold-summary-only-light',
    );
    await tester.ensureVisible(find.byKey(const Key('masraweya-work')));
    await tester.pump();
    await saveShot(tester, 'masraweya-gold-light-work');

    final field = find.byKey(const Key('masraweya-entry-value-field-0'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await saveShot(tester, 'masraweya-gold-light-keyboard');
    tester.view.resetViewInsets();
    await tester.pump();

    final before = tester.getSize(
      find.byKey(const Key('masraweya-work-table')),
    );
    for (var i = 0; i < 3; i++) {
      final add = find.byKey(const Key('masraweya-add-row'));
      await tester.ensureVisible(add);
      await tester.pump();
      await tester.tap(add);
      await _settle(tester);
    }
    expect(
      tester.getSize(find.byKey(const Key('masraweya-work-table'))).height,
      greaterThan(before.height),
    );
    await tester.ensureVisible(find.byKey(const Key('masraweya-work-table')));
    await tester.pump();
    await saveShot(tester, 'masraweya-gold-light-added-rows');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeShell)),
    );
    container.read(themeModeProvider.notifier).toggle();
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const Key('masraweya-summary')));
    await tester.pump();
    await saveShot(tester, 'masraweya-gold-dark-summary');
    await saveBoundaryShot(
      tester,
      find.byKey(const Key('masraweya-summary-capture')),
      'masraweya-gold-summary-only-dark',
    );
    await tester.ensureVisible(find.byKey(const Key('masraweya-work-table')));
    await tester.pump();
    await saveShot(tester, 'masraweya-gold-dark-added-rows');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);

  testWidgets('row totals on a large phone, fake data', (tester) async {
    const viewport = Size(440, 956);
    await pumpFakeApp(tester, size: viewport);
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/masraweya');

    Future<void> add() async {
      final button = find.byKey(const Key('masraweya-add-row'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await _settle(tester);
    }

    Future<void> type(String key, String value) async {
      final field = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.enterText(field, value);
      await tester.pump();
    }

    await add();
    await add();
    await type('masraweya-entry-value-field-1', '1000');
    await type('masraweya-entry-commission-field-1', '25');
    await type('masraweya-entry-value-field-2', '0');
    await type('masraweya-entry-commission-field-2', '0');
    await add();
    await type('masraweya-entry-value-field-3', '400');
    expect(find.text('1,025'), findsWidgets);
    expect(find.text('ج.م'), findsWidgets);
    expect(find.text('3,050'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('masraweya-work-table')));
    await tester.pump();
    await saveShot(tester, 'masraweya-egp-left-light');
    await saveBoundaryShot(
      tester,
      find.byKey(const Key('masraweya-summary-capture')),
      'masraweya-egp-left-summary',
    );

    final focus = find.byKey(const Key('masraweya-entry-value-field-1'));
    await tester.ensureVisible(focus);
    await tester.tap(focus);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await saveShot(tester, 'masraweya-row-totals-focused');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);

  testWidgets('treasury egyptian amount has ج.م on the left', (tester) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/treasury');
    await tester.ensureVisible(find.text('95,000'));
    await tester.pump();
    final symbol = tester.getRect(find.text('ج.م').first);
    final number = tester.getRect(find.text('95,000').first);
    expect(symbol.center.dx, lessThan(number.center.dx));
    await saveShot(tester, 'treasury-egp-left-light');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
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
