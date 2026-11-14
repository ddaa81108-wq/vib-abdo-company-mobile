import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/push_payload.dart';
import 'package:vib_abdo_company_mobile/notifications/tray_notification.dart';

void main() {
  test('the expanded shade uses the server detail fields and the time', () {
    final note = notificationFromShadeData({
      'notificationId': 'n-93',
      'operationType': 'customer.payment',
      'actorName': 'أحمد',
      'actorRole': 'employee',
      'subjectName': 'سالم',
      'subjectSection': 'customers',
      'amountUnits': '1500',
      'paymentMode': 'partial',
      'createdAt': '2026-11-14T13:25:00Z',
      'phone': '0910000000',
      'token': 'secret',
    });
    final tray = trayForServer(note);
    expect(tray.body, contains('أحمد'));
    expect(tray.body, contains('سالم'));
    expect(tray.body, contains('1,500'));
    expect(tray.body, contains('د.ل'));
    expect(tray.body, contains('تسديدًا جزئيًا'));
    expect(tray.body, contains('2026/11/14'));
    expect(tray.body, isNot(contains('091')));
    expect(tray.body, isNot(contains('secret')));
    expect(tray.publicBody, lockScreenNotificationText);
    expect(tray.publicBody, isNot(contains('سالم')));
  });

  test(
    'a push with only the current data keys keeps the server shade body',
    () {
      final note = notificationFromShadeData(
        {
          'notificationId': 'n-94',
          'recipientUserId': 'u-1',
          'operationType': 'customer.debt',
        },
        serverBody:
            'أحمد — إضافة دين عميل\nsubjectName: سالم\namountUnits: 1500',
      );
      final tray = trayForServer(
        note,
        serverBody:
            'أحمد — إضافة دين عميل\nsubjectName: سالم\namountUnits: 1500',
      );
      expect(tray.body, contains('أحمد — إضافة دين عميل'));
      expect(tray.body, contains('subjectName: سالم'));
      expect(tray.publicBody, isNot(contains('سالم')));
    },
  );
}
