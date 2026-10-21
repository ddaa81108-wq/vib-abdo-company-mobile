import 'package:flutter/foundation.dart';

/// Compile-time `USE_FAKE_API`. The same default as [ApiConfig.fromEnvironment].
const bool kUseFakeApiFromEnvironment = bool.fromEnvironment(
  'USE_FAKE_API',
  defaultValue: true,
);

/// Printed by the compiler when a release build sets `USE_FAKE_API=true`.
const String releaseFakeApiRejectedMessage =
    'Release builds cannot use the fake API. '
    'Pass --dart-define=USE_FAKE_API=false.';

/// Fails compilation of a release binary when the fake API is selected.
///
/// The assert is evaluated with the constant, including release AOT. It is not
/// a runtime `assert` (those are stripped from release). Omitting the define
/// selects the default `USE_FAKE_API=true`, so `flutter build apk --release`
/// and `flutter build appbundle --release` fail until the define is false.
/// Debug, profile, and `flutter test` leave `dart.vm.product` unset.
class ReleaseFakeApiGuard {
  const ReleaseFakeApiGuard()
    : assert(
        !const bool.fromEnvironment('dart.vm.product') ||
            !kUseFakeApiFromEnvironment,
        releaseFakeApiRejectedMessage,
      );
}

/// Referenced from `main` and from tests so the const assert stays reachable.
const ReleaseFakeApiGuard releaseFakeApiGuard = ReleaseFakeApiGuard();

/// Runtime rejection when release code is asked to construct the fake client.
///
/// Covers `ApiConfig(useFakeApi: true)` built by hand, which the const assert
/// (it only sees `--dart-define`) does not. [releaseMode] is for tests.
void rejectFakeApiInRelease(bool useFakeApi, {bool? releaseMode}) {
  final release = releaseMode ?? kReleaseMode;
  if (release && useFakeApi) {
    throw StateError(releaseFakeApiRejectedMessage);
  }
}
