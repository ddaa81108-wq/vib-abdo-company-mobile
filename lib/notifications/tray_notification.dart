import 'package:flutter_api_layer/api_layer.dart';

import 'notification_channels.dart';
import 'push_payload.dart';

/// Lock-screen line. No employee name, amount, phone, or token.
const lockScreenNotificationText = 'إشعار جديد';

/// One system-tray post on `vib_collections_alerts`.
///
/// [title] and [body] are the private text. [publicTitle] and [publicBody]
/// are the lock-screen version. [androidId] is a stable hash of [tag], and
/// [tag] is the notification id, so a repeat replaces the existing row.
class TrayNotification {
  const TrayNotification({
    required this.androidId,
    required this.tag,
    required this.title,
    required this.body,
    required this.publicTitle,
    required this.publicBody,
    required this.payload,
  });

  final int androidId;
  final String tag;
  final String title;
  final String body;
  final String publicTitle;
  final String publicBody;

  /// Passed through to [NotificationOpener] on tap. This is the notification id.
  final String payload;

  Map<String, Object> get channelArguments => {
    'id': androidId,
    'tag': tag,
    'title': title,
    'body': body,
    'publicTitle': publicTitle,
    'publicBody': publicBody,
    'payload': payload,
    'channelId': NotificationChannels.collectionsId,
  };
}

/// Stable 31-bit Android id. Dart's [String.hashCode] is not stable across
/// isolates, so a repeat has to use this hash or it would stack.
int stableAndroidNotificationId(String notificationId) {
  var hash = 0x811c9dc5;
  for (final unit in notificationId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  if (hash == 0) return 1;
  return hash;
}

/// Private body is the operation label, plus the server employee name when
/// that row has one. Title is [AppNotification.systemName]. The public
/// version is the system name plus [lockScreenNotificationText].
///
/// Title, body, the raw operation, the related id, amounts, phones, and
/// tokens on the row are not copied. [employeeName] is the only personal
/// field, and only in the private body.
TrayNotification trayForServer(AppNotification notification) {
  final label = operationLabel(notification.operationType);
  final name = notification.employeeName?.trim();
  final body = (name == null || name.isEmpty) ? label : '$label · $name';
  final system = _systemName(notification.systemName);
  return TrayNotification(
    androidId: stableAndroidNotificationId(notification.notificationId),
    tag: notification.notificationId,
    title: system,
    body: body,
    publicTitle: system,
    publicBody: lockScreenNotificationText,
    payload: notification.notificationId,
  );
}

String _systemName(String systemName) {
  final system = systemName.trim();
  if (system.isEmpty) return 'VIB';
  return system;
}
