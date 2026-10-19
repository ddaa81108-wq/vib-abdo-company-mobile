import 'common.dart';

/// GET /api/notifications?before -> { items: [...], unreadCount }
/// The web client builds the notification TEXT locally from `action` + `details`.
/// We request server-provided `title`/`body`, per API contract; until then the app shows
/// a static label per `action` and NEVER renders numbers from `details`.
class NotificationDto {
  const NotificationDto(
      {required this.id,
      required this.action,
      this.title,
      this.body,
      this.section,
      this.entityId,
      this.readAt,
      this.createdAt});
  final String id;
  final String action; // audit event name, e.g. collection.submit
  final String? title;
  final String? body;
  final String? section;
  final String? entityId;
  final DateTime? readAt;
  final DateTime? createdAt;
  bool get isRead => readAt != null;

  factory NotificationDto.fromJson(Json j) => NotificationDto(
        id: str(j['id']),
        action: str(j['action'] ?? j['type']),
        title: strOrNull(j['title']),
        body: strOrNull(j['body']),
        section: strOrNull(j['section']),
        entityId: strOrNull(j['entityId'] ?? j['aggregateId']),
        readAt: dateOrNull(j['readAt']),
        createdAt: dateOrNull(j['createdAt']),
      );
}

/// Badge = server `unreadCount` only. The app never increments/decrements it.
class NotificationsPage {
  const NotificationsPage(
      {required this.items, required this.unreadCount, this.nextBefore});
  final List<NotificationDto> items;
  final int unreadCount;
  final String? nextBefore;
  factory NotificationsPage.fromData(Object? data) {
    final d = asJson(data);
    final items = asJsonList(d['items'])
        .map(NotificationDto.fromJson)
        .toList(growable: false);
    return NotificationsPage(
      items: items,
      unreadCount: intOrNull(d['unreadCount']) ?? 0,
      nextBefore: strOrNull(d['nextBefore'] ?? d['nextCursor']),
    );
  }
}
