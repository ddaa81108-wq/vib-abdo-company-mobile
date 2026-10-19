import 'package:flutter_api_layer/data/models/account_models.dart';
import 'package:flutter_api_layer/data/models/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a missing ledger sequence stays null', () {
    final entry = LedgerEntryDto.fromJson({
      'id': 'tx',
      'type': 'debt',
      'status': 'posted',
    });
    expect(entry.sequence, isNull);
    expect(
      LedgerEntryDto.fromJson({
        'id': 'tx',
        'type': 'debt',
        'status': 'posted',
        'sequence': 4,
      }).sequence,
      4,
    );
  });

  test('a missing unread count stays null', () {
    expect(NotificationsPage.fromData({'items': []}).unreadCount, isNull);
    expect(
      NotificationsPage.fromData({'items': [], 'unreadCount': 0}).unreadCount,
      0,
    );
    expect(
      NotificationsPage.fromData({'items': [], 'unreadCount': 3}).unreadCount,
      3,
    );
  });
}
