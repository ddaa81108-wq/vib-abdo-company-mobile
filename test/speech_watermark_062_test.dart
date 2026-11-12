import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/speech_watermark.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';

void main() {
  final log = StringBuffer('VIB-FIX-062 speech timeline\n');

  AppNotification row(String id, DateTime at) => AppNotification(
    notificationId: id,
    systemName: 'الاستلامات',
    employeeName: 'موظف تجريبي',
    operationType: NotificationOperationType.approve,
    operationTypeRaw: 'collection.submit',
    relatedRef: null,
    createdAt: at,
    readAt: null,
    recipientUserId: 'u_12',
    actorName: 'موظف تجريبي',
  );

  test('cold start, resume backlog, foreground arrival, and duplicates', () {
    final speech = SpeechWatermark();
    final backlog = [
      row('77', DateTime.utc(2026, 10, 18, 10)),
      row('81', DateTime.utc(2026, 10, 18, 11)),
    ];

    // Cold start: the list loaded while the voice was not armed is silent.
    expect(speech.holding, isTrue);
    speech.baseline(backlog);
    log.writeln('cold start: backlog 77,81 marked seen, spoken=none');
    expect(speech.holding, isFalse);
    expect(speech.admit(backlog[0]), isFalse);
    expect(speech.admit(backlog[1]), isFalse);

    // The same id never speaks twice, even if it is offered again.
    final repeat = row('81', DateTime.utc(2026, 10, 18, 11));
    expect(speech.admit(repeat), isFalse);
    log.writeln('duplicate 81: silent');

    // A row that arrives after the watermark is spoken once.
    final fresh = row('90', DateTime.utc(2026, 10, 18, 12));
    expect(speech.admit(fresh), isTrue);
    expect(speech.admit(fresh), isFalse);
    log.writeln('foreground arrival 90: spoken once');

    // Resume: hold, then the rows that landed while away become the backlog.
    speech.hold();
    expect(speech.holding, isTrue);
    final whileAway = row('95', DateTime.utc(2026, 10, 18, 13));
    expect(speech.admit(whileAway), isFalse);
    speech.baseline([whileAway, fresh]);
    log.writeln('resume: 95 arrived while away, marked seen, not spoken');
    expect(speech.admit(whileAway), isFalse);

    final afterResume = row('100', DateTime.utc(2026, 10, 18, 14));
    expect(speech.admit(afterResume), isTrue);
    log.writeln('after resume: 100 spoken once');

    final file = File('/opt/cursor/artifacts/speech-062-log.txt');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(log.toString());
    expect(log.toString(), contains('spoken once'));
  });

  test(
    'opening the app does not speak the unread list already on the server',
    () async {
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
        fakeLatency: Duration.zero,
      );
      await layer.session.login(username: 'employee.demo', password: 'x');
      final container = ProviderContainer(
        overrides: [apiLayerProvider.overrideWithValue(layer)],
      );
      addTearDown(container.dispose);
      addTearDown(layer.dispose);
      final events = <String>[];
      container.listen(foregroundNotificationsProvider, (_, next) {
        next.whenData((item) => events.add(item.notificationId));
      });

      await container.read(notificationsProvider.future);
      await container
          .read(notificationsProvider.notifier)
          .refresh(announce: true);
      expect(events, isEmpty, reason: 'cold start backlog stays silent');

      container.read(notificationsProvider.notifier).holdSpeech();
      await container
          .read(notificationsProvider.notifier)
          .refresh(announce: true);
      expect(events, isEmpty, reason: 'resume snapshot stays silent');

      await container
          .read(notificationsProvider.notifier)
          .ingestOne(
            AppNotification(
              notificationId: 'fresh-062',
              systemName: 'الاستلامات',
              employeeName: 'موظف تجريبي',
              operationType: NotificationOperationType.approve,
              operationTypeRaw: 'collection.submit',
              relatedRef: null,
              createdAt: DateTime.utc(2026, 10, 21),
              readAt: null,
              recipientUserId: 'u_12',
              actorName: 'موظف تجريبي',
            ),
            source: NotificationSource.push,
          );
      expect(events, ['fresh-062']);
      await container
          .read(notificationsProvider.notifier)
          .ingestOne(
            AppNotification(
              notificationId: 'fresh-062',
              systemName: 'الاستلامات',
              employeeName: 'موظف تجريبي',
              operationType: NotificationOperationType.approve,
              operationTypeRaw: 'collection.submit',
              relatedRef: null,
              createdAt: DateTime.utc(2026, 10, 21),
              readAt: null,
              recipientUserId: 'u_12',
              actorName: 'موظف تجريبي',
            ),
            source: NotificationSource.push,
          );
      expect(events, ['fresh-062']);
    },
  );
}
