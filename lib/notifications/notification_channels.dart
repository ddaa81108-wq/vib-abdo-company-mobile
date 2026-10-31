/// Stable Android notification ids.
///
/// Runtime permission requests are not made here. `POST_NOTIFICATIONS` is
/// declared in the manifest; another change asks for it.
///
/// Channel ids are part of the device install. Renaming one creates a second
/// channel and leaves the old one in system settings.
abstract final class NotificationChannels {
  /// General and collections alerts. Manifest FCM meta-data uses this id.
  static const collectionsId = 'vib_collections_alerts';

  /// Arabic label. Includes the manifest display name `VIB`.
  static const collectionsName = 'تنبيهات VIB';

  static const collectionsDescription = 'تنبيهات عامة وتنبيهات التحصيل';

  /// Drawable resource, no extension. White-on-transparent status icon.
  static const smallIcon = 'ic_stat_notification';

  /// `android:label` on the application tag. Not the in-app screen title.
  static const manifestLabel = 'VIB';

  static const postNotificationsPermission =
      'android.permission.POST_NOTIFICATIONS';

  static const applicationId = 'com.vip2100.vib';

  static const fcmDefaultIconMeta =
      'com.google.firebase.messaging.default_notification_icon';

  static const fcmDefaultChannelMeta =
      'com.google.firebase.messaging.default_notification_channel_id';

  /// `POST_NOTIFICATIONS` is a runtime permission from Android 13.
  static const runtimePermissionSdk = 33;

  /// minSdk must stay at or below Android 10 so API 29 devices still install.
  static const minSdkCeiling = 29;

  /// Id used by the emulator probe. Not a user-facing alert id.
  static const probeNotificationId = 91001;

  static const collections = NotificationChannelSpec(
    id: collectionsId,
    name: collectionsName,
    description: collectionsDescription,
    showBadge: true,
    importance: NotificationImportance.high,
  );
}

enum NotificationImportance { high }

class NotificationChannelSpec {
  const NotificationChannelSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.showBadge,
    required this.importance,
  });

  final String id;
  final String name;
  final String description;

  /// Android 8+ `NotificationChannel.setShowBadge`.
  final bool showBadge;
  final NotificationImportance importance;
}

class AndroidNotificationRequest {
  const AndroidNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.channel,
    required this.icon,
    this.badgeCount,
  });

  final int id;
  final String title;
  final String body;
  final NotificationChannelSpec channel;
  final String icon;

  /// Passed to `NotificationCompat.setNumber` when the launcher supports it.
  final int? badgeCount;
}

/// Launcher badge count. Unsupported launchers ignore the number; this does
/// not call a vendor badge API.
abstract final class LauncherBadge {
  static int? countFor(int? count) {
    if (count == null || count < 0) return null;
    return count;
  }
}
