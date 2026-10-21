import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../error_handling/error_handler.dart';
import 'android_notification_controller.dart';
import 'notification_channels.dart';

/// SDK and permission helpers on `app/android_notifications`.
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
  var _initialized = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({required String androidIcon}) async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings(androidIcon),
      ),
    );
    _initialized = true;
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
  Future<bool?> requestAndroidPermission() =>
      _android?.requestNotificationsPermission() ?? Future<bool?>.value();

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

/// Creates the channel and, on API 33+, asks for `POST_NOTIFICATIONS`.
///
/// Failures are reported and swallowed. The rest of the app still starts.
abstract final class AndroidNotificationSetup {
  static Future<void> start({
    void Function(Object error, StackTrace stackTrace)? onError,
    NotificationPlatform? platform,
    int? sdkInt,
  }) async {
    try {
      final resolved = platform ?? FlutterLocalNotificationsAdapter();
      await AndroidNotificationController(
        platform: resolved,
        sdkInt: sdkInt ?? 0,
      ).initialize();
      final resolvedSdk = sdkInt ?? await AndroidNotificationBridge.sdkInt();
      await AndroidNotificationController(
        platform: resolved,
        sdkInt: resolvedSdk,
      ).requestPermission();
    } catch (error, stackTrace) {
      if (onError != null) {
        onError(error, stackTrace);
      } else {
        const ErrorHandler().report(error, stackTrace);
      }
    }
  }
}

/// Runs [AndroidNotificationSetup.start] after the first frame, when the
/// activity can host the system permission dialog.
class AndroidNotificationsBootstrap extends StatefulWidget {
  const AndroidNotificationsBootstrap({
    required this.child,
    this.onError,
    super.key,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<AndroidNotificationsBootstrap> createState() =>
      _AndroidNotificationsBootstrapState();
}

class _AndroidNotificationsBootstrapState
    extends State<AndroidNotificationsBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AndroidNotificationSetup.start(onError: widget.onError));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
