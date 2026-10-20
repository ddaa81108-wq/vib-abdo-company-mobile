import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_api_layer/core/security/screen_security.dart';

import 'platform_screen_security.dart';

/// Re-applies window protection for the whole app.
///
/// Every route can show a password or financial data, so this never calls
/// [ScreenSecurity.disable]. The recents thumbnail is blank because
/// `FLAG_SECURE` is window-wide, not a per-screen blur.
class ScreenProtection extends StatefulWidget {
  const ScreenProtection({
    required this.child,
    this.security = const PlatformScreenSecurity(),
    super.key,
  });

  final Widget child;
  final ScreenSecurity security;

  @override
  State<ScreenProtection> createState() => ScreenProtectionState();
}

class ScreenProtectionState extends State<ScreenProtection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.security.enable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.security.enable());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
