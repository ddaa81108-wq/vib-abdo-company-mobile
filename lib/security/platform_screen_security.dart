import 'package:flutter/services.dart';
import 'package:flutter_api_layer/core/security/screen_security.dart';

/// Asks Android to set `FLAG_SECURE` on the activity window.
///
/// [disable] does not clear the flag. The activity sets it before the first
/// frame, and this call repeats it on startup and whenever the app resumes.
class PlatformScreenSecurity implements ScreenSecurity {
  const PlatformScreenSecurity();

  static const channelName = 'app/screen_security';
  static const _channel = MethodChannel(channelName);

  @override
  Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('enable');
    } catch (_) {
      // Tests and non-Android targets have no channel. The activity flag
      // still covers a real Android process.
    }
  }

  @override
  Future<void> disable() async {}
}
