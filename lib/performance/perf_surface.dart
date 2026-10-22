import 'package:flutter/foundation.dart';

/// Where a Phase 7 measurement is running.
///
/// `PERF_SURFACE=auto` (the default) treats Android as an emulator. A
/// physical-device run passes `PERF_SURFACE=device`. Host `flutter test`
/// is [host] and does not fail frame or startup budgets.
enum PerfSurface { host, emulator, device }

PerfSurface currentPerfSurface() {
  const name = String.fromEnvironment('PERF_SURFACE', defaultValue: 'auto');
  return switch (name) {
    'host' => PerfSurface.host,
    'emulator' => PerfSurface.emulator,
    'device' => PerfSurface.device,
    _ =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? PerfSurface.emulator
          : PerfSurface.host,
  };
}

bool releaseProtocolSurface(PerfSurface surface) =>
    surface == PerfSurface.emulator || surface == PerfSurface.device;
