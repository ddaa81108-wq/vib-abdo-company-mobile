import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

/// Waits until the frame is idle. Do not call this while a fake pause gate
/// is still open: a paused read never settles.
Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> go(WidgetTester tester, String path) async {
  goNow(tester, path);
  await settle(tester);
}

/// Navigates and returns immediately. Used while [FakeApiClient] is paused.
void goNow(WidgetTester tester, String path) {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
}

/// Pumps a few frames without requiring the tree to go idle.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('not found: $finder');
}
