import 'package:flutter_api_layer/api_layer.dart';

import 'device_token_registrar.dart';
import 'notification_permission_service.dart';

/// Registers the device when notification permission is granted, and
/// unregisters it when permission is denied or later revoked.
///
/// Signed out, this does nothing. Logout already forgets the token.
Future<void> syncNotificationRegistration({
  required SessionState session,
  required DeviceTokenRegistrar registrar,
  required NotificationPermissionService permission,
}) async {
  if (session is! SessionAuthenticated) return;
  if (await permission.granted) {
    await registrar.registerIfReady(signedIn: true);
    return;
  }
  await registrar.forget();
}
