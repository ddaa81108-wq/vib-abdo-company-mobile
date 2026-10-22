import 'notification_channels.dart';
import 'system_tray_platform.dart';
import 'tray_notification.dart';

/// Android notification operations the controller can run without the plugin.
///
/// Checking and posting only. Requesting `POST_NOTIFICATIONS` is a separate
/// change and is not part of this interface.
abstract class NotificationPlatform {
  Future<void> initialize({
    required String androidIcon,
    void Function(String? payload)? onSelect,
  });

  Future<void> createAndroidChannel(NotificationChannelSpec channel);

  Future<bool?> androidNotificationsEnabled();

  Future<void> showAndroid(AndroidNotificationRequest request);

  Future<void> cancel(int id);
}

/// Creates the collections channel and posts an alert when the system allows it.
class AndroidNotificationController {
  AndroidNotificationController({
    required this.platform,
    SystemTrayPlatform? tray,
  }) : tray = tray ?? const MethodChannelSystemTray();

  final NotificationPlatform platform;

  /// Activity channel that sets the lock-screen public version.
  final SystemTrayPlatform tray;

  Future<void> initialize({void Function(String? payload)? onSelect}) async {
    await platform.initialize(
      androidIcon: NotificationChannels.smallIcon,
      onSelect: onSelect,
    );
    await platform.createAndroidChannel(NotificationChannels.collections);
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

  /// Private alert on `vib_collections_alerts`, with [notification]'s public
  /// title and body for the lock screen. Returns false when notifications
  /// are disabled.
  Future<bool> showPrivateAlert(TrayNotification notification) async {
    final enabled = await platform.androidNotificationsEnabled();
    if (enabled == false) return false;
    return tray.show(notification);
  }

  Future<void> cancel(int id) => platform.cancel(id);
}
