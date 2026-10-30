import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/notifications_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

void main() {
  Future<({ApiLayer layer, ProviderContainer container})> signedIn(
    String username,
  ) async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    await layer.session.login(username: username, password: 'x');
    final container = ProviderContainer(
      overrides: [apiLayerProvider.overrideWithValue(layer)],
    );
    addTearDown(container.dispose);
    addTearDown(layer.dispose);
    return (layer: layer, container: container);
  }

  AppNotification sample({
    required String id,
    String? recipientUserId,
    DateTime? readAt,
    DateTime? createdAt,
    String raw = 'approve',
  }) {
    return AppNotification(
      notificationId: id,
      systemName: 'sys',
      employeeName: null,
      operationType: NotificationOperationType.parse(raw),
      operationTypeRaw: raw,
      relatedRef: null,
      createdAt: createdAt ?? DateTime.utc(2026, 10, 19),
      readAt: readAt,
      recipientUserId: recipientUserId,
    );
  }

  test('mark-read updates readAt and the server count, without a second decrement', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    expect(
      await container.read(unreadNotificationsCountProvider.future),
      1,
    );
    final page = await container.read(notificationsProvider.future);
    expect(page.items.single.id, '77');
    expect(
      container.read(notificationsStateProvider),
      isA<NotificationsReady>(),
    );

    await container.read(notificationsProvider.notifier).markRead('77');
    final ready =
        container.read(notificationsStateProvider) as NotificationsReady;
    expect(ready.items.single.isRead, isTrue);
    expect(container.read(unreadNotificationsCountProvider).value, 0);

    await container.read(notificationsProvider.notifier).markRead('77');
    expect(container.read(unreadNotificationsCountProvider).value, 0);
    expect(
      (harness.layer.client as FakeApiClient).notificationMutationApplies,
      2,
    );
  });

  test('a second mark while the first is in flight sends one request', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    final fake = harness.layer.client as FakeApiClient;
    await container.read(notificationsProvider.future);
    final notifier = container.read(notificationsProvider.notifier);
    final writes =
        harness.layer.notifications as RemoteNotificationsRepository;

    final one = notifier.markRead('77');
    final two = notifier.markRead('77');
    await Future.wait([one, two]);
    expect(fake.notificationMutationApplies, 1);
    expect(writes.attemptedWriteRequestIds, hasLength(1));

    final allOne = notifier.markAllRead();
    final allTwo = notifier.markAllRead();
    await Future.wait([allOne, allTwo]);
    expect(fake.notificationMutationApplies, 2);
    expect(writes.attemptedWriteRequestIds, hasLength(2));
  });

  test('push and poll dedupe, and a push does not increment the count', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    final events = <AppNotification>[];
    container.listen(foregroundNotificationsProvider, (_, next) {
      next.whenData(events.add);
    });
    await container.read(notificationsProvider.future);
    await container.read(unreadNotificationsCountProvider.future);
    expect(events, isEmpty);

    final notifier = container.read(notificationsProvider.notifier);
    await notifier.ingestOne(
      sample(id: 'kept-null'),
      source: NotificationSource.fetch,
    );
    expect(_ids(container), contains('kept-null'));
    expect(events, isEmpty);

    await notifier.ingestOne(
      sample(id: 'push-foreign', recipientUserId: 'u_20'),
      source: NotificationSource.push,
    );
    expect(_ids(container), isNot(contains('push-foreign')));

    await notifier.ingestOne(
      sample(id: 'push-blank'),
      source: NotificationSource.push,
    );
    expect(_ids(container), isNot(contains('push-blank')));

    await notifier.ingestOne(
      sample(id: 'push-1', recipientUserId: 'u_12'),
      source: NotificationSource.push,
    );
    expect(events.map((item) => item.notificationId), ['push-1']);
    expect(container.read(unreadNotificationsCountProvider).value, 1);

    await notifier.ingestOne(
      sample(id: 'push-1', recipientUserId: 'u_12'),
      source: NotificationSource.poll,
      announce: true,
    );
    expect(events.map((item) => item.notificationId), ['push-1']);

    final read = sample(
      id: '77',
      recipientUserId: 'u_12',
      readAt: DateTime.utc(2026, 10, 21),
    );
    await notifier.ingest([read], source: NotificationSource.fetch);
    expect(
      container
          .read(notificationsProvider)
          .value!
          .appNotifications
          .firstWhere((item) => item.notificationId == '77')
          .isRead,
      isTrue,
    );
    await notifier.ingest(
      [sample(id: '77', recipientUserId: 'u_12')],
      source: NotificationSource.poll,
    );
    expect(
      container
          .read(notificationsProvider)
          .value!
          .appNotifications
          .firstWhere((item) => item.notificationId == '77')
          .isRead,
      isTrue,
    );
  });

  test('a failed unread-count route uses the list count, then keeps the previous one', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    final fake = harness.layer.client as FakeApiClient;
    expect(await container.read(unreadNotificationsCountProvider.future), 1);
    await container.read(notificationsProvider.future);

    fake.failUnreadCountRemaining = 1;
    fake.stageNotification(
      {
        'id': 'fresh',
        'action': 'approve',
        'createdAt': '2026-10-20T12:00:00Z',
      },
      unreadCount: 4,
    );
    await container.read(notificationsProvider.notifier).refresh();
    final updated = container.read(notificationsProvider).value!;
    expect(updated.items.map((item) => item.id), containsAll(['fresh', '77']));
    expect(updated.items, hasLength(2));
    expect(updated.unreadCount, 4);
    expect(container.read(unreadNotificationsCountProvider).value, 4);

    fake.omitUnreadCount = true;
    fake.failUnreadCountRemaining = 1;
    fake.stageNotification({
      'id': 'later',
      'action': 'reject',
      'createdAt': '2026-10-21T12:00:00Z',
    });
    await container.read(notificationsProvider.notifier).refresh();
    final kept = container.read(notificationsProvider).value!;
    expect(kept.items.map((item) => item.id), contains('later'));
    expect(kept.unreadCount, 4);
    expect(container.read(unreadNotificationsCountProvider).value, 4);
  });

  test('mark-read reads the list count when the write omits it and the count route is 404', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    final fake = harness.layer.client as FakeApiClient;
    expect(await container.read(unreadNotificationsCountProvider.future), 1);
    await container.read(notificationsProvider.future);
    fake.omitNotificationWriteUnreadCount = true;
    fake.failUnreadCountRemaining = 1;

    await container.read(notificationsProvider.notifier).markRead('77');

    final ready =
        container.read(notificationsStateProvider) as NotificationsReady;
    expect(ready.items.single.isRead, isTrue);
    // Production has no unread-count route. Its 404 falls back to
    // `unreadCount` on GET /api/notifications, which is 0 after the read.
    expect(container.read(unreadNotificationsCountProvider).value, 0);
  });

  test('refresh can announce a new unread row and the initial list does not', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    final events = <AppNotification>[];
    container.listen(foregroundNotificationsProvider, (_, next) {
      next.whenData(events.add);
    });
    await container.read(notificationsProvider.future);
    await container.read(notificationsProvider.notifier).refresh();
    expect(events, isEmpty);

    await container.read(notificationsProvider.notifier).ingestOne(
      sample(
        id: 'fresh',
        recipientUserId: 'u_12',
        createdAt: DateTime.utc(2026, 10, 20),
      ),
      source: NotificationSource.fetch,
      announce: true,
    );
    expect(events.map((item) => item.notificationId), ['fresh']);
    final ids = _ids(container);
    expect(ids.first, 'fresh');
    expect(ids, contains('77'));
  });

  test('logout and account switch drop the previous list and count', () async {
    final harness = await signedIn('employee.demo');
    final container = harness.container;
    container.listen(sessionStateProvider, (_, _) {});
    expect(
      (await container.read(notificationsProvider.future)).items.single.id,
      '77',
    );

    await harness.layer.session.logout();
    final cleared = await container.read(notificationsProvider.future);
    expect(cleared.items, isEmpty);
    expect(await container.read(unreadNotificationsCountProvider.future), 0);

    await harness.layer.session.login(
      username: 'other.employee',
      password: 'x',
    );
    final next = await container.read(notificationsProvider.future);
    expect(next.items.map((item) => item.id), ['88', 'n_20']);
    expect(next.items.map((item) => item.id), isNot(contains('77')));
    expect(await container.read(unreadNotificationsCountProvider.future), 2);
  });

  test('forbidden hides the server sentence and other errors stay failures', () async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);

    final forbidden = ProviderContainer(
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        notificationsProvider.overrideWith(_ForbiddenNotes.new),
      ],
    );
    addTearDown(forbidden.dispose);
    await expectLater(
      forbidden.read(notificationsProvider.future),
      throwsA(isA<ForbiddenException>()),
    );
    final denied = forbidden.read(notificationsStateProvider);
    expect(denied, isA<NotificationsForbidden>());
    expect((denied as NotificationsForbidden).message, AppStrings.forbidden);
    expect(denied.message.contains('سر'), isFalse);

    final failed = ProviderContainer(
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        notificationsProvider.overrideWith(_NetworkNotes.new),
      ],
    );
    addTearDown(failed.dispose);
    await expectLater(
      failed.read(notificationsProvider.future),
      throwsA(isA<NetworkException>()),
    );
    expect(
      failed.read(notificationsStateProvider),
      isA<NotificationsFailure>(),
    );

    final gate = Completer<void>();
    final loading = ProviderContainer(
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        notificationsProvider.overrideWith(() => _HoldNotes(gate)),
      ],
    );
    addTearDown(loading.dispose);
    expect(loading.read(notificationsStateProvider), isA<NotificationsLoading>());
    gate.complete();
    await loading.read(notificationsProvider.future);
    expect(loading.read(notificationsStateProvider), isA<NotificationsEmpty>());
  });
}

List<String> _ids(ProviderContainer container) => [
  for (final item
      in container.read(notificationsProvider).value!.appNotifications)
    item.notificationId,
];

class _ForbiddenNotes extends NotificationsController {
  @override
  Future<NotificationsPage> build() async {
    throw const ForbiddenException(code: 'FORBIDDEN', message: 'سر الخادم');
  }
}

class _NetworkNotes extends NotificationsController {
  @override
  Future<NotificationsPage> build() async {
    throw const NetworkException();
  }
}

class _HoldNotes extends NotificationsController {
  _HoldNotes(this.gate);

  final Completer<void> gate;

  @override
  Future<NotificationsPage> build() async {
    await gate.future;
    return const NotificationsPage(items: [], unreadCount: 0);
  }
}
