import 'perf_surface.dart';

/// Engineering budgets for the separate performance workflow.
///
/// These numbers can fail that workflow. They are not the acceptance Pass
/// for P7-23 or P7-24. The Phase 7 matrix (PR #48) says Ali writes the
/// numeric threshold before the first protocol run. Until that number is
/// filled in, the result template stays `recorded`.
abstract final class PerfBudget {
  /// Android vitals treats a cold start over 5s as slow.
  /// Device D only. Emulators are not this budget.
  static const deviceColdStartMs = 5000;

  /// Emulator hang only. SwiftShader startup is not device D.
  static const emulatorColdStartHangMs = 20000;

  /// Home-after-login on a live staging origin. RTT dominates, so this is
  /// a hang ceiling, not a Pass line.
  static const stagingHomeHangMs = 60000;

  /// Opening a screen against the fake client with zero latency.
  static const deviceScreenOpenMs = 2000;
  static const emulatorScreenOpenMs = 5000;

  /// One dropped frame at 60Hz is ~16.7ms. Two frames is the device fail line.
  static const deviceWorstBuildMs = 32;

  /// Average build time of the measured scroll, device only.
  static const deviceAverageBuildMs = 16.7;

  /// A freeze on either an emulator or a device.
  static const stallMs = 500;

  /// Prior fat release APK was about 58.9 MiB. Warn, then fail.
  static const apkWarnBytes = 64 * 1024 * 1024;
  static const apkFailBytes = 72 * 1024 * 1024;

  static int? coldStartFailMs(PerfSurface surface) => switch (surface) {
    PerfSurface.device => deviceColdStartMs,
    PerfSurface.emulator => emulatorColdStartHangMs,
    PerfSurface.host => null,
  };

  static int? screenOpenFailMs(PerfSurface surface) => switch (surface) {
    PerfSurface.device => deviceScreenOpenMs,
    PerfSurface.emulator => emulatorScreenOpenMs,
    PerfSurface.host => null,
  };

  static bool failWorstBuild(PerfSurface surface, double millis) {
    if (millis > stallMs) {
      return surface != PerfSurface.host;
    }
    if (surface != PerfSurface.device) return false;
    return millis > deviceWorstBuildMs;
  }

  static bool failAverageBuild(PerfSurface surface, double millis) {
    if (surface != PerfSurface.device) return false;
    return millis > deviceAverageBuildMs;
  }
}
