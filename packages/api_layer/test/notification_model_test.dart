import 'package:flutter_api_layer/data/models/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('id wins over notificationId and unknown operations do not throw', () {
    final parsed = AppNotification.fromJson({
      'id': 'a',
      'notificationId': 'b',
      'operationType': 'not-a-real-op',
      'createdAt': 'nope',
      'readAt': 'also-nope',
      'relatedRef': {'type': 'account'},
    });

    expect(parsed.notificationId, 'a');
    expect(parsed.operationType, NotificationOperationType.unknown);
    expect(parsed.operationTypeRaw, 'not-a-real-op');
    expect(parsed.createdAt, DateTime.utc(1970));
    expect(parsed.readAt, isNull);
    expect(parsed.isRead, isFalse);
    expect(parsed.relatedRef, isNull);
    expect(parsed.systemName, '');
    expect(parsed.employeeName, isNull);
    expect(parsed.recipientUserId, isNull);
  });

  test('notificationId is the fallback and known actions map', () {
    final parsed = AppNotification.fromJson({
      'notificationId': 'b',
      'action': 'collection.submit',
      'readAt': '2026-10-21T18:00:00Z',
    });

    expect(parsed.notificationId, 'b');
    expect(parsed.operationType, NotificationOperationType.collectionSubmit);
    expect(parsed.isRead, isTrue);

    const known = {
      'collection.submit': NotificationOperationType.collectionSubmit,
      'approve': NotificationOperationType.approve,
      'approved': NotificationOperationType.approved,
      'reject': NotificationOperationType.reject,
      'rejected': NotificationOperationType.rejected,
      'cash_received': NotificationOperationType.cashReceived,
    };
    for (final entry in known.entries) {
      expect(
        AppNotification.fromJson({
          'id': '1',
          'operationType': entry.key,
        }).operationType,
        entry.value,
      );
    }
    expect(
      AppNotification.fromJson({
        'id': '1',
        'action': 'collection.approve',
      }).operationType,
      NotificationOperationType.unknown,
    );
  });

  test('relatedRef accepts an object, a JSON string, flat push keys, or section', () {
    expect(
      AppNotification.fromJson({
        'id': '1',
        'relatedRef': {'type': 'receipt', 'id': 'r9'},
      }).relatedRef,
      isA<NotificationRelatedRef>()
          .having((ref) => ref.type, 'type', 'receipt')
          .having((ref) => ref.id, 'id', 'r9'),
    );
    expect(
      AppNotification.fromPushPayload({
        'id': 'p',
        'systemName': 'sys',
        'employeeName': 'ن',
        'operationType': 'cash_received',
        'relatedRef': '{"type":"account","id":"c_55"}',
        'recipientUserId': 'u_12',
        'createdAt': '2026-10-18T12:00:00Z',
        'readAt': '',
      }),
      isA<AppNotification>()
          .having((item) => item.systemName, 'systemName', 'sys')
          .having((item) => item.employeeName, 'employeeName', 'ن')
          .having(
            (item) => item.operationType,
            'operationType',
            NotificationOperationType.cashReceived,
          )
          .having((item) => item.relatedRef?.type, 'type', 'account')
          .having((item) => item.relatedRef?.id, 'id', 'c_55')
          .having((item) => item.recipientUserId, 'recipient', 'u_12')
          .having((item) => item.readAt, 'readAt', isNull),
    );
    expect(
      AppNotification.fromPushPayload({
        'notificationId': 'flat',
        'system': 'alt',
        'relatedRefType': 'collection',
        'relatedRefId': 'c1',
      }).relatedRef?.type,
      'collection',
    );
    final fromSection = AppNotification.fromJson({
      'id': '77',
      'section': 'collections',
      'entityId': 'sb_1',
    });
    expect(fromSection.relatedRef?.type, 'collections');
    expect(fromSection.relatedRef?.id, 'sb_1');
    expect(fromSection.toDto().section, 'collections');
  });

  test('pagination cursors are optional', () {
    expect(
      NotificationsPage.fromData({'items': []}).nextBefore,
      isNull,
    );
    expect(
      NotificationsPage.fromData({
        'items': [],
        'nextCursor': 'cursor-1',
      }).nextBefore,
      'cursor-1',
    );
    final page = NotificationsPage.fromData({
      'items': [
        {'id': '1', 'action': 'approve'},
      ],
      'nextBefore': '1',
    });
    expect(page.nextBefore, '1');
    expect(page.appNotifications.single.notificationId, '1');
    expect(page.items.single.id, '1');
  });
}
