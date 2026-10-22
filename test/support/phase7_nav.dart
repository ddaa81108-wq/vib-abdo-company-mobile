import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

/// Waits until the frame is idle. Do not call this while a fake pause gate
/// is still open: a paused read never settles.
///
/// The fake client arms a zero-delay timer during the frame that
/// [pumpAndSettle] treats as idle. That timer is pumped until a pump no
/// longer leaves another one behind. A spinning indicator is not pumped
/// here; callers that pause a mutation use [pumpUntilFound] instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(Duration.zero);
    if (!tester.binding.hasScheduledFrame) return;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  }
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
