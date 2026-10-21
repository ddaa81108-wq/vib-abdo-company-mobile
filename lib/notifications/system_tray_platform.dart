import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_channels.dart';
import 'tray_notification.dart';

/// Posts one private notification. The activity channel sets the public version.
abstract interface class SystemTrayPlatform {
  Future<bool> show(TrayNotification notification);
}

class RecordingSystemTrayPlatform implements SystemTrayPlatform {
  final List<TrayNotification> posts = [];

  @override
  Future<bool> show(TrayNotification notification) async {
    posts.add(notification);
    return true;
  }
}

/// `MainActivity` method `app/system_tray`. Sets visibility private and a
/// public version the Flutter plugin cannot set.
class MethodChannelSystemTray implements SystemTrayPlatform {
  const MethodChannelSystemTray();

  static const channelName = 'app/system_tray';
  static const channel = MethodChannel(channelName);

  @override
  Future<bool> show(TrayNotification notification) async {
    final posted = await channel.invokeMethod<bool>(
      'show',
      notification.channelArguments,
    );
    return posted ?? false;
  }
}

/// UI isolate uses the activity channel. A WorkManager isolate has no
/// activity channel, so it posts through `flutter_local_notifications` with
/// visibility private. Android then redacts the lock screen instead of
/// showing the employee name. The activity path still sets the explicit
/// public title and body.
class FallbackSystemTray implements SystemTrayPlatform {
  FallbackSystemTray({
    SystemTrayPlatform? primary,
    Future<bool> Function(TrayNotification notification)? pluginShow,
  }) : _primary = primary ?? const MethodChannelSystemTray(),
       _pluginShow = pluginShow ?? showPrivateWithPlugin;

  final SystemTrayPlatform _primary;
  final Future<bool> Function(TrayNotification notification) _pluginShow;

  @override
  Future<bool> show(TrayNotification notification) async {
    try {
      return await _primary.show(notification);
    } on MissingPluginException {
      return _pluginShow(notification);
    }
  }
}

/// Plugin post used when the activity channel is not on this isolate.
///
/// Visibility is private. This plugin build cannot call `setPublicVersion`,
/// so a secure lock screen shows the system redaction rather than [body].
Future<bool> showPrivateWithPlugin(TrayNotification notification) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: InitializationSettings(
      android: AndroidInitializationSettings(NotificationChannels.smallIcon),
    ),
  );
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      NotificationChannels.collectionsId,
      NotificationChannels.collectionsName,
      description: NotificationChannels.collectionsDescription,
      importance: Importance.high,
      showBadge: true,
    ),
  );
  await plugin.show(
    id: notification.androidId,
    title: notification.title,
    body: notification.body,
    payload: notification.payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationChannels.collectionsId,
        NotificationChannels.collectionsName,
        channelDescription: NotificationChannels.collectionsDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: NotificationChannels.smallIcon,
        visibility: NotificationVisibility.private,
        tag: notification.tag,
        channelShowBadge: true,
      ),
    ),
  );
  return true;
}
