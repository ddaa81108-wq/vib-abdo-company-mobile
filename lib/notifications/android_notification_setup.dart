import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../error_handling/error_handler.dart';
import 'android_notification_controller.dart';
import 'notification_channels.dart';

/// SDK lookup on `app/android_notifications`.
///
/// The integration test reads `sdkInt` so it can tell an implicit API 29
/// install from an API 33+ grant. Production code does not request permission.
abstract final class AndroidNotificationBridge {
  static const channelName = 'app/android_notifications';
  static const channel = MethodChannel(channelName);

  static Future<int> sdkInt() async {
    final value = await channel.invokeMethod<int>('sdkInt');
    if (value == null) {
      throw StateError('Android sdkInt was not returned.');
    }
    return value;
  }
}

/// `flutter_local_notifications` behind [NotificationPlatform].
class FlutterLocalNotificationsAdapter implements NotificationPlatform {
  FlutterLocalNotificationsAdapter([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({
    required String androidIcon,
    void Function(String? payload)? onSelect,
  }) async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(androidIcon),
      ),
      onDidReceiveNotificationResponse: onSelect == null
          ? null
          : (response) => onSelect(response.payload),
    );
    if (onSelect == null) return;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      onSelect(launch?.notificationResponse?.payload);
    }
  }

  @override
  Future<void> createAndroidChannel(NotificationChannelSpec channel) async {
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        channel.id,
        channel.name,
        description: channel.description,
        importance: _importance(channel.importance),
        showBadge: channel.showBadge,
      ),
    );
  }

  @override
  Future<bool?> androidNotificationsEnabled() =>
      _android?.areNotificationsEnabled() ?? Future<bool?>.value();

  @override
  Future<void> showAndroid(AndroidNotificationRequest request) {
    return _plugin.show(
      id: request.id,
      title: request.title,
      body: request.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          request.channel.id,
          request.channel.name,
          channelDescription: request.channel.description,
          importance: _importance(request.channel.importance),
          priority: Priority.high,
          icon: request.icon,
          channelShowBadge: request.channel.showBadge,
          number: request.badgeCount,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Importance _importance(NotificationImportance importance) {
    switch (importance) {
      case NotificationImportance.high:
        return Importance.high;
    }
  }
}

/// Creates the collections channel. Does not request `POST_NOTIFICATIONS`.
///
/// Failures are reported and swallowed. The rest of the app still starts.
abstract final class AndroidNotificationSetup {
  static Future<void>? _chain;

  static Future<void> start({
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function(String? payload)? onSelect,
    NotificationPlatform? platform,
  }) {
    final previous = _chain ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        final resolved = platform ?? FlutterLocalNotificationsAdapter();
        await AndroidNotificationController(platform: resolved)
            .initialize(onSelect: onSelect);
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        } else {
          const ErrorHandler().report(error, stackTrace);
        }
      }
    });
    _chain = next;
    return next;
  }
}
