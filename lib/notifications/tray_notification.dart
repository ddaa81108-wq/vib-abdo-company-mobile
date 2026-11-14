import 'package:flutter_api_layer/api_layer.dart';

import '../features/notifications/notification_sentence.dart';
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

/// Private body is the Arabic operation sentence (section, name, amount,
/// currency, actor) plus the time, when the server row has those fields.
/// The public lock-screen line stays [lockScreenNotificationText].
TrayNotification trayForServer(
  AppNotification notification, {
  String? serverBody,
}) {
  final body = shadeBody(notification, serverBody: serverBody);
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

/// Expanded shade text. Uses only fields [AppNotification] already parsed
/// from `GET /api/notifications` or from a push `data` map. A push stub with
/// no actor and no details keeps the short operation label.
String shadeBody(AppNotification notification, {String? serverBody}) {
  final sentence = notificationSentence(notification);
  // [AppNotification.body] is not the shade. A list row can carry a number
  // there; only an explicit FCM notification body is display text.
  final stored = serverBody?.trim();
  final label = operationLabel(notification.operationType);
  final name = notification.employeeName?.trim();
  final headline = (sentence != null && sentence.isNotEmpty)
      ? sentence
      : (stored != null && stored.isNotEmpty)
      ? stored
      : ((name == null || name.isEmpty) ? label : '$label · $name');
  final when = shadeTime(notification.createdAt);
  if (when == null || headline.contains(when)) return headline;
  return '$headline\n$when';
}

/// Local clock time. Epoch and unparsed dates are omitted.
String? shadeTime(DateTime createdAt) {
  final local = createdAt.toLocal();
  if (local.year < 2000) return null;
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/$month/$day $hour:$minute';
}

String _systemName(String systemName) {
  final system = systemName.trim();
  if (system.isEmpty) return 'VIB';
  return system;
}
