import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_sentence.dart';
import 'package:vib_abdo_company_mobile/notifications/notification_announcer.dart';

AppNotification row({
  required String action,
  String actor = 'أحمد',
  String role = 'employee',
  Map<String, dynamic> details = const {},
}) {
  return AppNotification(
    notificationId: '1',
    systemName: '',
    employeeName: null,
    operationType: NotificationOperationType.parse(action),
    operationTypeRaw: action,
    relatedRef: null,
    createdAt: DateTime.utc(2026, 11, 10),
    readAt: null,
    recipientUserId: null,
    actorName: actor,
    actorRole: role,
    details: details,
  );
}

void main() {
  test('a collection notice is an Arabic sentence, not the raw action', () {
    final sentence = notificationSentence(
      row(
        action: 'collection.submit',
        role: 'admin',
        details: {
          'paymentMode': 'partial',
          'amountUnits': 1500,
          'subjectName': 'محمد',
          'subjectSection': 'customer_debts',
        },
      ),
    );
    expect(
      sentence,
      'الإداري أحمد سجّل تسديدًا جزئيًا بقيمة 1,500 د.ل للعميل محمد.',
    );
    expect(sentence, isNot(contains('collection.submit')));
    expect(
      spokenNotificationText(sentence!),
      'الإداري أحمد سجّل تسديدًا جزئيًا بقيمة 1500 دينار ليبي للعميل محمد.',
    );
  });

  test(
    'speech runs only when النطق is on, and the tone follows الصوت',
    () async {
      final announcer = RecordingNotificationAnnouncer();
      final note = row(
        action: 'customer.create',
        details: {'subjectName': 'محمد'},
      );
      await announceNewNotification(
        note: note,
        preferences: {'soundEnabled': true, 'speechEnabled': false},
        announcer: announcer,
      );
      expect(announcer.spoken, isEmpty);
      expect(announcer.tones, 1);

      await announceNewNotification(
        note: note,
        preferences: {'soundEnabled': true, 'speechEnabled': true},
        announcer: announcer,
      );
      expect(announcer.spoken, hasLength(1));
      expect(announcer.spoken.single, contains('إضافة عميل'));
      expect(announcer.tones, 2);

      await announceNewNotification(
        note: note,
        preferences: {'soundEnabled': false, 'speechEnabled': true},
        announcer: announcer,
      );
      expect(announcer.tones, 2);
      expect(announcer.spoken, hasLength(2));
    },
  );
}
