/// Present only when this binary is not a release build and the build asked
/// for the capture harness. Release (`dart.vm.product`) never registers it.
const bool kCaptureHarness =
    bool.fromEnvironment('CAPTURE_HARNESS', defaultValue: false) &&
    !bool.fromEnvironment('dart.vm.product');

const captureHarnessPath = '/capture-harness';
