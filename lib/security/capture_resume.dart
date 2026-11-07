import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';

/// After the activity resumes, the native window is still secure until this
/// sends the current verified role again. A signed-out session stays secure.
class CaptureResume extends ConsumerStatefulWidget {
  const CaptureResume({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CaptureResume> createState() => _CaptureResumeState();
}

class _CaptureResumeState extends ConsumerState<CaptureResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(apiLayerProvider).session.reapplyCapture();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
