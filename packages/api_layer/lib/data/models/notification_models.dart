import 'dart:convert';

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
  const NotificationsPage({
    required this.items,
    required this.unreadCount,
    this.nextBefore,
    this.appNotifications = const [],
  });
  final List<NotificationDto> items;

  /// Same rows as [items], parsed for the phase 6 controller.
  ///
  /// Empty when a caller built the page from [NotificationDto]s only.
  final List<AppNotification> appNotifications;

  /// Null when the server omits `unreadCount`. The badge stays hidden; 0 is a real count.
  final int? unreadCount;

  /// 🔶 `before` / `nextBefore` / `nextCursor` are not confirmed.
  /// Either cursor name is accepted. Missing pagination fields stay null.
  final String? nextBefore;
  factory NotificationsPage.fromData(Object? data) {
    final d = asJson(data);
    final rawItems = asJsonList(d['items']);
    return NotificationsPage(
      items: rawItems.map(NotificationDto.fromJson).toList(growable: false),
      appNotifications:
          rawItems.map(AppNotification.fromJson).toList(growable: false),
      unreadCount: intOrNull(d['unreadCount']),
      nextBefore: strOrNull(d['nextBefore'] ?? d['nextCursor']),
    );
  }

  NotificationsPage withAppNotifications(
    List<AppNotification> records, {
    int? unreadCount,
  }) {
    return NotificationsPage(
      items: [for (final item in records) item.toDto()],
      appNotifications: records,
      unreadCount: unreadCount ?? this.unreadCount,
      nextBefore: nextBefore,
    );
  }
}

/// Known `operationType` / `action` values. Anything else is [unknown].
///
/// The raw text is kept on [AppNotification.operationTypeRaw]. Parsing never
/// throws. 🔶 The vocabulary is not a confirmed server enum. `collection.submit`
/// is the value the fake fixture already uses. The other five are the words
/// the current notification labels already switch on, without the
/// `collection.` prefix except for `collection.submit`.
enum NotificationOperationType {
  collectionSubmit,
  approve,
  approved,
  reject,
  rejected,
  cashReceived,
  unknown;

  static NotificationOperationType parse(String raw) => switch (raw) {
        'collection.submit' => collectionSubmit,
        'approve' => approve,
        'approved' => approved,
        'reject' => reject,
        'rejected' => rejected,
        'cash_received' => cashReceived,
        _ => unknown,
      };
}

/// Linked record for a later tap. Both parts are required; otherwise the
/// whole object is null. `type` is free text.
class NotificationRelatedRef {
  const NotificationRelatedRef({required this.type, required this.id});

  final String type;
  final String id;
}

/// One notification row.
///
/// `id` is the confirmed JSON field. `notificationId` is only a fallback.
/// 🔶 `systemName`, `employeeName`, `operationType`, `relatedRef`, and
/// `recipientUserId` are not confirmed server fields.
class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.systemName,
    required this.employeeName,
    required this.operationType,
    required this.operationTypeRaw,
    required this.relatedRef,
    required this.createdAt,
    required this.readAt,
    required this.recipientUserId,
    this.title,
    this.body,
  });

  final String notificationId;
  final String systemName;
  final String? employeeName;
  final NotificationOperationType operationType;
  final String operationTypeRaw;
  final NotificationRelatedRef? relatedRef;

  /// Missing or unparseable JSON becomes Unix epoch so a bad row cannot throw.
  final DateTime createdAt;
  final DateTime? readAt;

  /// 🔶 Unconfirmed. Null when the server omits it (list/poll are session-scoped).
  final String? recipientUserId;

  /// Optional display text the current client already parses. Not required.
  final String? title;
  final String? body;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final raw = _operationRaw(json);
    return AppNotification(
      notificationId: _notificationId(json),
      systemName: _text(json['systemName']) ?? _text(json['system']) ?? '',
      employeeName: _text(json['employeeName']),
      operationType: NotificationOperationType.parse(raw),
      operationTypeRaw: raw,
      relatedRef: _relatedRef(json),
      createdAt: dateOrNull(json['createdAt']) ?? DateTime.utc(1970),
      readAt: dateOrNull(json['readAt']),
      recipientUserId: _text(json['recipientUserId']),
      title: _text(json['title']),
      body: _text(json['body']),
    );
  }

  /// Push data payloads are flat string maps. Same tolerant parser as [fromJson].
  factory AppNotification.fromPushPayload(Map<String, dynamic> payload) =>
      AppNotification.fromJson(payload);

  factory AppNotification.fromDto(NotificationDto dto) {
    final section = dto.section?.trim();
    final entity = dto.entityId?.trim();
    final hasRef = section != null &&
        section.isNotEmpty &&
        entity != null &&
        entity.isNotEmpty;
    return AppNotification(
      notificationId: dto.id,
      systemName: '',
      employeeName: null,
      operationType: NotificationOperationType.parse(dto.action),
      operationTypeRaw: dto.action,
      relatedRef:
          hasRef ? NotificationRelatedRef(type: section, id: entity) : null,
      createdAt: dto.createdAt ?? DateTime.utc(1970),
      readAt: dto.readAt,
      recipientUserId: null,
      title: dto.title,
      body: dto.body,
    );
  }

  NotificationDto toDto() => NotificationDto(
        id: notificationId,
        action: operationTypeRaw,
        title: title,
        body: body,
        section: relatedRef?.type,
        entityId: relatedRef?.id,
        readAt: readAt,
        createdAt: createdAt,
      );

  /// Incoming fields fill gaps. [readAt] is the later of the two timestamps.
  /// A null [readAt] does not clear one that is already set. [createdAt] stays
  /// on the first real value so ordering does not jump.
  AppNotification mergeWith(AppNotification incoming) {
    final nextRaw = incoming.operationTypeRaw.isNotEmpty
        ? incoming.operationTypeRaw
        : operationTypeRaw;
    return AppNotification(
      notificationId: notificationId,
      systemName:
          incoming.systemName.isNotEmpty ? incoming.systemName : systemName,
      employeeName: incoming.employeeName ?? employeeName,
      operationType: NotificationOperationType.parse(nextRaw),
      operationTypeRaw: nextRaw,
      relatedRef: incoming.relatedRef ?? relatedRef,
      createdAt: _preferCreated(createdAt, incoming.createdAt),
      readAt: _laterReadAt(readAt, incoming.readAt),
      recipientUserId: incoming.recipientUserId ?? recipientUserId,
      title: incoming.title ?? title,
      body: incoming.body ?? body,
    );
  }

  AppNotification withReadAt(DateTime value) => AppNotification(
        notificationId: notificationId,
        systemName: systemName,
        employeeName: employeeName,
        operationType: operationType,
        operationTypeRaw: operationTypeRaw,
        relatedRef: relatedRef,
        createdAt: createdAt,
        readAt: value,
        recipientUserId: recipientUserId,
        title: title,
        body: body,
      );
}

/// 🔶 Proposed write body. The current client ignores the response today.
/// `unreadCount` is null when the server omits it; the controller then
/// refetches the unread-count route instead of inventing a number.
class NotificationWriteResult {
  const NotificationWriteResult({
    required this.unreadCount,
    this.readAt,
    this.notification,
  });

  final int? unreadCount;
  final DateTime? readAt;
  final AppNotification? notification;

  factory NotificationWriteResult.fromData(Object? data) {
    final json = asJson(data);
    final raw = json['notification'];
    return NotificationWriteResult(
      unreadCount: intOrNull(json['unreadCount']),
      readAt: dateOrNull(json['readAt']),
      notification: raw is Map ? AppNotification.fromJson(asJson(raw)) : null,
    );
  }
}

String _notificationId(Map<String, dynamic> json) {
  final id = _text(json['id']);
  if (id != null) return id;
  return _text(json['notificationId']) ?? '';
}

String _operationRaw(Map<String, dynamic> json) {
  for (final key in ['operationType', 'action', 'type']) {
    final text = _text(json[key]);
    if (text != null) return text;
  }
  return '';
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  if (text.isEmpty) return null;
  return text;
}

NotificationRelatedRef? _relatedRef(Map<String, dynamic> json) {
  final nested = json['relatedRef'];
  if (nested is Map) {
    final ref = _pair(asJson(nested), 'type', 'id');
    if (ref != null) return ref;
  } else if (nested is String && nested.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(nested);
      if (decoded is Map) {
        final ref = _pair(asJson(decoded), 'type', 'id');
        if (ref != null) return ref;
      }
    } catch (_) {
      // 🔶 A push string that is not JSON is ignored. section/entityId may still match.
    }
  }
  final flat = _pair(json, 'relatedRefType', 'relatedRefId');
  if (flat != null) return flat;
  final section = _text(json['section']);
  final entity = _text(json['entityId'] ?? json['aggregateId']);
  if (section == null || entity == null) return null;
  return NotificationRelatedRef(type: section, id: entity);
}

NotificationRelatedRef? _pair(
  Map<String, dynamic> json,
  String typeKey,
  String idKey,
) {
  final type = _text(json[typeKey]);
  final id = _text(json[idKey]);
  if (type == null || id == null) return null;
  return NotificationRelatedRef(type: type, id: id);
}

DateTime? _laterReadAt(DateTime? current, DateTime? incoming) {
  if (current == null) return incoming;
  if (incoming == null) return current;
  return incoming.isAfter(current) ? incoming : current;
}

DateTime _preferCreated(DateTime current, DateTime incoming) {
  if (current.millisecondsSinceEpoch == 0 &&
      incoming.millisecondsSinceEpoch != 0) {
    return incoming;
  }
  return current;
}
