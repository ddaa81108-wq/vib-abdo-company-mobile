import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'shell_screenshots_test.dart';
import 'support/pump_app.dart';

/// Logical viewport 440×956, DPR 1, headless flutter_tester. Fake sessions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin collections layout, fake data, light and dark', (
    tester,
  ) async {
    await _boot(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/collections');

    await _scrollTo(tester, 0);
    await saveShot(tester, 'collections-admin-light-top');
    await _show(tester, const Key('collections-list'));
    await saveShot(tester, 'collections-admin-light-cards');
    await _tap(tester, const Key('employee-totals-toggle'));
    await _show(tester, const Key('employee-totals'));
    await saveShot(tester, 'collections-admin-light-totals');
    await _tap(tester, const Key('collections-payroll'));
    await _scrollTo(tester, 0);
    await saveShot(tester, 'collections-admin-light-payroll');
    await _tap(tester, const Key('collections-payroll-back'));

    _toggleTheme(tester);
    await tester.pumpAndSettle();
    await _scrollTo(tester, 0);
    await saveShot(tester, 'collections-admin-dark-top');
    await _show(tester, const Key('collections-list'));
    await saveShot(tester, 'collections-admin-dark-cards');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);

  testWidgets('employee collections layout, fake data, light and dark', (
    tester,
  ) async {
    await _boot(tester);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await _go(tester, '/collections');

    expect(find.byKey(const Key('collections-filter-card')), findsNothing);
    expect(find.byKey(const Key('employee-totals-toggle')), findsNothing);
    expect(find.byKey(const Key('close-batch')), findsNothing);
    await _scrollTo(tester, 0);
    await saveShot(tester, 'collections-employee-light-top');
    await _show(tester, const Key('collections-list'));
    await saveShot(tester, 'collections-employee-light-cards');
    await _tap(tester, const Key('collections-payroll'));
    await _scrollTo(tester, 0);
    await saveShot(tester, 'collections-employee-light-payroll');
    await _tap(tester, const Key('collections-payroll-back'));

    _toggleTheme(tester);
    await tester.pumpAndSettle();
    await _scrollTo(tester, 0);
    await saveShot(tester, 'collections-employee-dark-top');
    await _show(tester, const Key('collections-list'));
    await saveShot(tester, 'collections-employee-dark-cards');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

Future<void> _boot(WidgetTester tester) async {
  await pumpFakeApp(tester, size: const Size(440, 956));
  await tester.runAsync(loadScreenshotFonts);
  await tester.pump();
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}

void _toggleTheme(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(HomeShell.shellKey)),
  );
  container.read(themeModeProvider.notifier).toggle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await _show(tester, key);
  await tester.tap(find.byKey(key), warnIfMissed: true);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, double offset) async {
  final scrollable = find
      .descendant(
        of: find.byKey(CollectionsScreen.screenKey),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(offset.clamp(0, position.maxScrollExtent));
  await tester.pump();
}

Future<void> _show(WidgetTester tester, Key key) async {
  final scrollable = find
      .descendant(
        of: find.byKey(CollectionsScreen.screenKey),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 16; i++) {
    final rect = tester.getRect(find.byKey(key));
    if ((rect.top - 180).abs() < 24) return;
    final next = position.pixels + (rect.top - 180);
    position.jumpTo(next.clamp(0, position.maxScrollExtent));
    await tester.pump();
  }
}
