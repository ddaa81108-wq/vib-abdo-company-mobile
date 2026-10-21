import 'dart:convert';

import 'package:flutter_api_layer/api_layer.dart';

/// Keys a push map is allowed to keep before [AppNotification.fromPushPayload].
///
/// `systemName` is included because the shade text is that name plus a fixed
/// operation label. `employeeName`, amounts, phones, titles, and tokens are
/// not in this set. `relatedRef` keeps only `type` and `id`.
const pushPayloadKeys = <String>{
  'notificationId',
  'recipientUserId',
  'operationType',
  'relatedRef',
  'relatedRefType',
  'relatedRefId',
  'createdAt',
  'systemName',
};

/// Drops every key that is not on the push whitelist.
Map<String, dynamic> whitelistPushPayload(Map<String, dynamic> raw) {
  final out = <String, dynamic>{};
  void copy(String key) {
    if (raw.containsKey(key)) out[key] = raw[key];
  }

  copy('notificationId');
  copy('recipientUserId');
  copy('operationType');
  copy('createdAt');
  copy('systemName');
  copy('relatedRefType');
  copy('relatedRefId');

  final ref = raw['relatedRef'];
  final pair = _relatedPair(ref);
  if (pair != null) out['relatedRef'] = pair;
  return out;
}

Map<String, dynamic>? _relatedPair(Object? ref) {
  if (ref is Map) {
    return _pair(ref);
  }
  if (ref is String && ref.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(ref);
      if (decoded is Map) return _pair(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

Map<String, dynamic>? _pair(Map<dynamic, dynamic> ref) {
  final type = ref['type'];
  final id = ref['id'];
  if (type == null && id == null) return null;
  return {'type': ?type, 'id': ?id};
}

/// Shade text. Fixed labels only. The raw operation string is not copied,
/// and neither is [AppNotification.title], body, employee name, or the ref id.
String genericNotificationText(AppNotification notification) {
  final label = switch (notification.operationType) {
    NotificationOperationType.collectionSubmit => 'استلام جديد',
    NotificationOperationType.approve ||
    NotificationOperationType.approved => 'اعتماد',
    NotificationOperationType.reject ||
    NotificationOperationType.rejected => 'رفض',
    NotificationOperationType.cashReceived => 'استلام نقد',
    NotificationOperationType.unknown => 'إشعار',
  };
  final system = notification.systemName.trim();
  if (system.isEmpty) return label;
  return '$system · $label';
}
