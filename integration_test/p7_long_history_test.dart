import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_api_layer/data/fake/fake_large_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/performance/perf_budget.dart';
import 'package:vib_abdo_company_mobile/performance/perf_surface.dart';

import '../test/support/pump_app.dart';

/// P7-24 frame timings and the P7-25 page walk on a device or emulator.
///
/// Host `flutter test` reports the numbers and does not fail a noisy clock.
/// Acceptance Pass is not claimed: Ali writes that threshold.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P7-24 P7-25 long history scroll and frame timings', (
    tester,
  ) async {
    const surfaceName = String.fromEnvironment(
      'PERF_SURFACE',
      defaultValue: 'auto',
    );
    final surface = currentPerfSurface();
    phase7('p7_24_surface', surface.name);
    phase7('p7_24_surface_define', surfaceName);
    phase7('p7_25_pages', FakeLargeCatalog.ledgerPageCount);

    await pumpFakeApp(
      tester,
      fakeDataset: FakeDataset.large,
      size: const Size(800, 1400),
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final router = GoRouter.of(tester.element(find.byKey(HomeShell.shellKey)));

    final openWatch = Stopwatch()..start();
    router.go('/customers/${FakeLargeCatalog.longLedgerAccountId}');
    await _until(tester, const Key('load-older'));
    openWatch.stop();
    final openMs = openWatch.elapsedMilliseconds;
    phase7('p7_24_screen_open_ms', openMs);
    final openBudget = PerfBudget.screenOpenFailMs(surface);
    if (openBudget != null && openMs > openBudget) {
      fail(
        'P7-24 screen open ${openMs}ms exceeded engineering budget ${openBudget}ms',
      );
    }

    var taps = 0;
    while (find.byKey(const Key('load-older')).evaluate().isNotEmpty) {
      taps++;
      expect(taps, lessThanOrEqualTo(FakeLargeCatalog.ledgerPageCount));
      await _pressLoadOlder(tester);
    }
    expect(taps, FakeLargeCatalog.ledgerPageCount - 1);
    expect(find.byKey(const Key('ledger-pages-20')), findsOneWidget);
    phase7('p7_25_pages_loaded', taps + 1);
    phase7('p7_25_acceptance', 'widget-walk-complete');

    final list = find.byKey(const Key('ledger-older-list'));
    expect(list, findsOneWidget);
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    WidgetsBinding.instance.addTimingsCallback(collect);
    final scrollWatch = Stopwatch()..start();
    await tester.fling(list, const Offset(0, -600), 2000);
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    scrollWatch.stop();
    WidgetsBinding.instance.removeTimingsCallback(collect);

    final builds = [
      for (final timing in timings) timing.buildDuration.inMicroseconds / 1000,
    ];
    final worst = builds.isEmpty
        ? null
        : builds.reduce((a, b) => a > b ? a : b);
    final average = builds.isEmpty
        ? null
        : builds.reduce((a, b) => a + b) / builds.length;
    phase7('p7_24_frame_count', builds.length);
    phase7('p7_24_worst_build_ms', worst ?? 'empty');
    phase7('p7_24_average_build_ms', average ?? 'empty');
    phase7('p7_24_scroll_wall_ms', scrollWatch.elapsedMilliseconds);
    phase7('p7_24_acceptance', 'recorded');

    if (builds.isEmpty) {
      if (surface == PerfSurface.host) {
        phase7('p7_24_budget_result', 'report-only');
        return;
      }
      fail('P7-24 produced no frame timings on ${surface.name}');
    }
    final worstMs = worst!;
    final averageMs = average!;
    // The wall clock includes the test's own pumps. The freeze line is one
    // frame's build time, which [PerfBudget.failWorstBuild] already applies.
    final failed =
        PerfBudget.failWorstBuild(surface, worstMs) ||
        PerfBudget.failAverageBuild(surface, averageMs);
    if (surface == PerfSurface.host) {
      phase7('p7_24_budget_result', 'report-only');
      return;
    }
    phase7('p7_24_budget_result', failed ? 'exceeded' : 'within');
    if (failed) {
      fail(
        'P7-24 engineering budget exceeded on ${surface.name}: '
        'worst=${worstMs}ms average=${averageMs}ms. '
        'Acceptance stays recorded until Ali sets the protocol threshold.',
      );
    }
  });
}

void phase7(String key, Object value) {
  // ignore: avoid_print
  print('PHASE7 $key=$value');
}

Future<void> _until(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('missing $key');
}

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
