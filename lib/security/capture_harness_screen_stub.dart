import 'package:flutter/widgets.dart';

/// Release stand-in. It has no fixture identities and is not routed,
/// because [kCaptureHarness] is false in a release binary.
class CaptureHarnessScreen extends StatelessWidget {
  const CaptureHarnessScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
