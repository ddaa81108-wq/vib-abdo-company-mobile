import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/performance/perf_budget.dart';
import 'package:vib_abdo_company_mobile/performance/perf_surface.dart';

/// Engineering gates. A passing gate is not an acceptance Pass for P7-23
/// or P7-24. Ali writes that threshold.
void main() {
  test('P7-23 device cold start fails above 5s and the host only reports', () {
    expect(PerfBudget.deviceColdStartMs, 5000);
    expect(PerfBudget.emulatorColdStartHangMs, 20000);
    expect(PerfBudget.coldStartFailMs(PerfSurface.device), 5000);
    expect(PerfBudget.coldStartFailMs(PerfSurface.emulator), 20000);
    expect(PerfBudget.coldStartFailMs(PerfSurface.host), isNull);
  });

  test('P7-24 frame budgets fail a device jank and any freeze', () {
    expect(PerfBudget.failWorstBuild(PerfSurface.device, 33), isTrue);
    expect(PerfBudget.failWorstBuild(PerfSurface.device, 32), isFalse);
    expect(PerfBudget.failWorstBuild(PerfSurface.emulator, 40), isFalse);
    expect(PerfBudget.failWorstBuild(PerfSurface.emulator, 501), isTrue);
    expect(PerfBudget.failWorstBuild(PerfSurface.host, 800), isFalse);
    expect(PerfBudget.failAverageBuild(PerfSurface.device, 17), isTrue);
    expect(PerfBudget.failAverageBuild(PerfSurface.emulator, 40), isFalse);
    expect(PerfBudget.apkWarnBytes, 64 * 1024 * 1024);
    expect(PerfBudget.apkFailBytes, 72 * 1024 * 1024);
  });
}
