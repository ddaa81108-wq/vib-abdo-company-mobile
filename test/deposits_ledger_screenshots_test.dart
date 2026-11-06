import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'shell_screenshots_test.dart';
import 'support/pump_app.dart';

/// Logical viewport 440×956, DPR 1, headless flutter_tester. Fake data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deposit list tops, fake data, light and dark', (tester) async {
    await _boot(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/libyan-deposits');
    await saveShot(tester, 'deposits-libyan-light-top');
    await _go(tester, '/egyptian-deposits');
    await saveShot(tester, 'deposits-egyptian-light-top');
    _toggleTheme(tester);
    await tester.pumpAndSettle();
    await _go(tester, '/libyan-deposits');
    await saveShot(tester, 'deposits-libyan-dark-top');
    await _go(tester, '/egyptian-deposits');
    await saveShot(tester, 'deposits-egyptian-dark-top');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);

  testWidgets('ledger save tick stays on the left, two sideways positions', (
    tester,
  ) async {
    await _boot(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _go(tester, '/customers/c_55');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await saveShot(tester, 'ledger-tick-focused');
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('ledger-columns-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    await saveShot(tester, 'ledger-tick-scrolled-end');
    expect(find.byKey(const Key('save-movement')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(path);
  await tester.pumpAndSettle();
}

Future<void> _boot(WidgetTester tester) async {
  await pumpFakeApp(tester, size: const Size(440, 956));
  await tester.runAsync(loadScreenshotFonts);
  await tester.pump();
}

void _toggleTheme(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(HomeShell.shellKey)),
  );
  container.read(themeModeProvider.notifier).toggle();
}
