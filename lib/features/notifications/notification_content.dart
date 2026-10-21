import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/presentation.dart';
import '../../ui/strings.dart';

/// Headline for a list row and the foreground banner.
///
/// [AppNotification.employeeName] is included only when the server sent one,
/// so the separator is never left hanging.
String notificationHeadline(AppNotification note) {
  final parts = [
    notificationSystemName(note),
    notificationOperationLabel(note),
  ];
  final employee = note.employeeName?.trim();
  if (employee != null && employee.isNotEmpty) parts.add(employee);
  return parts.join(' · ');
}

String notificationSystemName(AppNotification note) {
  final name = note.systemName.trim();
  if (name.isEmpty) return AppStrings.notificationSystemFallback;
  return name;
}

/// Arabic label for a known [NotificationOperationType]. Unknown values use
/// [AppNotification.title], then the raw wire text, then a generic word.
String notificationOperationLabel(AppNotification note) {
  final known = switch (note.operationType) {
    NotificationOperationType.collectionSubmit => notificationFallback(
      'collection.submit',
    ),
    NotificationOperationType.approve || NotificationOperationType.approved =>
      notificationFallback('collection.approve'),
    NotificationOperationType.reject || NotificationOperationType.rejected =>
      notificationFallback('collection.reject'),
    NotificationOperationType.cashReceived => notificationFallback(
      'collection.cash_received',
    ),
    NotificationOperationType.unknown => null,
  };
  if (known != null) return known;
  final title = note.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final raw = note.operationTypeRaw.trim();
  if (raw.isNotEmpty) return raw;
  return notificationFallback('');
}

/// Optional server title and body, in that order. Empty strings are omitted.
List<String> notificationSecondaryLines(AppNotification note) {
  final lines = <String>[];
  final title = note.title?.trim();
  final body = note.body?.trim();
  if (title != null && title.isNotEmpty) lines.add(title);
  if (body != null && body.isNotEmpty) lines.add(body);
  return lines;
}

String notificationWhen(AppNotification note) => formatIsoDate(note.createdAt);
