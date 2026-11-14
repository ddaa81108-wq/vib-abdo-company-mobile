import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'notification_channels.dart';
import 'push_payload.dart';
import 'push_transport.dart';
import 'system_tray_platform.dart';
import 'tray_notification.dart';

/// Background and terminated entry. A message that already has an FCM
/// `notification` block was shown by Android, so this handler does not
/// post a second alert. A data-only message is the shade path: this
/// process posts one expanded BigText notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    return;
  }
  final tray = backgroundDataOnlyShade(
    hasNotificationPayload: message.notification != null,
    data: message.data,
    serverTitle: message.notification?.title,
    serverBody: message.notification?.body,
  );
  if (tray == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  await showPrivateWithPlugin(tray);
}

/// The tray a background or terminated data-only message posts.
/// Null when Android already displayed a `notification` block, or when
/// the data map has no notification id.
TrayNotification? backgroundDataOnlyShade({
  required bool hasNotificationPayload,
  required Map<String, dynamic> data,
  String? serverTitle,
  String? serverBody,
}) {
  if (!fcmShouldPostLocalAlert(
    inForeground: false,
    hasNotificationPayload: hasNotificationPayload,
  )) {
    return null;
  }
  final note = notificationFromShadeData(
    data,
    serverTitle: serverTitle,
    serverBody: serverBody,
  );
  if (note.notificationId.isEmpty) return null;
  return trayForServer(note, serverBody: serverBody);
}

/// Live Firebase Messaging. [start] returns false when the native config
/// is missing, and it never logs a token.
class PluginFcmRuntime implements FcmRuntime {
  var _listening = false;

  @override
  Future<bool> start({
    required void Function(String token) onToken,
    required void Function(Map<String, dynamic> payload) onMessage,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {
      return false;
    }
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      if (!_listening) {
        _listening = true;
        // HTTP v1 addresses a registration token from getToken, not the
        // Firebase Installation ID from register/onRegistered.
        // ignore: deprecated_member_use
        FirebaseMessaging.instance.onTokenRefresh.listen(
          onToken,
          onError: (_, _) {},
        );
        FirebaseMessaging.onMessage.listen((message) {
          final data = _data(message);
          if (message.notification != null) data['notificationPayload'] = true;
          onMessage(data);
        }, onError: (_, _) {});
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  @override
  bool inForeground() {
    final phase = WidgetsBinding.instance.lifecycleState;
    return phase == null || phase == AppLifecycleState.resumed;
  }
}

Map<String, dynamic> _data(RemoteMessage message) {
  final data = Map<String, dynamic>.from(message.data);
  data.putIfAbsent('channelId', () => NotificationChannels.collectionsId);
  final title = message.notification?.title;
  final body = message.notification?.body;
  if (title != null && title.trim().isNotEmpty) data['fcmTitle'] = title;
  if (body != null && body.trim().isNotEmpty) data['fcmBody'] = body;
  return data;
}

/// Chooses the process transport. An empty define tries Firebase and falls
/// back to the no-op when the config is absent, so SSE stays as it is.
///
/// [runtime] is for tests. Production passes nothing and uses the plugin.
Future<PushTransport> resolveAppPushTransport({FcmRuntime? runtime}) async {
  final raw = kPushTransportName.trim().toLowerCase();
  if (raw == 'fake') return FakePushTransport();
  if (raw == 'noop') return const NoopPushTransport();
  fcmRuntime = runtime ?? PluginFcmRuntime();
  final fcm = FcmPushTransport();
  final ready = await fcm.prepare();
  if (ready || raw == 'fcm') return fcm;
  return const NoopPushTransport();
}
