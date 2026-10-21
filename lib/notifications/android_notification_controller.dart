import 'notification_channels.dart';

/// Android notification operations the controller can run without the plugin.
abstract class NotificationPlatform {
  Future<void> initialize({required String androidIcon});

  Future<void> createAndroidChannel(NotificationChannelSpec channel);

  Future<bool?> requestAndroidPermission();

  Future<bool?> androidNotificationsEnabled();

  Future<void> showAndroid(AndroidNotificationRequest request);

  Future<void> cancel(int id);
}

/// Channel creation, the API 33 permission branch, and posting an alert.
class AndroidNotificationController {
  AndroidNotificationController({required this.platform, required this.sdkInt});

  final NotificationPlatform platform;
  final int sdkInt;

  Future<void> initialize() async {
    await platform.initialize(androidIcon: NotificationChannels.smallIcon);
    await platform.createAndroidChannel(NotificationChannels.collections);
  }

  Future<NotificationReadiness> requestPermission() async {
    if (!NotificationPermissionPolicy.runtimeRequestRequired(sdkInt)) {
      return NotificationReadiness.implicitlyGranted;
    }
    final granted = await platform.requestAndroidPermission();
    return NotificationPermissionPolicy.readinessFor(
      sdkInt: sdkInt,
      pluginGranted: granted,
    );
  }

  /// Posts on the collections channel when the system allows notifications.
  /// Returns false when they are disabled. A null answer still attempts a post.
  Future<bool> showCollectionsAlert({
    required int id,
    required String title,
    required String body,
    int? badgeCount,
  }) async {
    final enabled = await platform.androidNotificationsEnabled();
    if (enabled == false) return false;
    await platform.showAndroid(
      AndroidNotificationRequest(
        id: id,
        title: title,
        body: body,
        channel: NotificationChannels.collections,
        icon: NotificationChannels.smallIcon,
        badgeCount: LauncherBadge.countFor(badgeCount),
      ),
    );
    return true;
  }

  Future<void> cancel(int id) => platform.cancel(id);
}
