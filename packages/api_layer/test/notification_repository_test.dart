import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ApiLayer> signedIn(String username) async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: username, password: 'x');
    return api;
  }

  test('mark-read decrements once, replay does not, read-all sets zero', () async {
    final api = await signedIn('other.employee');
    final fake = api.client as FakeApiClient;

    expect(await api.notifications.serverUnreadCount(), 2);
    final page = await api.notifications.list();
    expect(page.items.map((item) => item.id), ['88', 'n_20']);
    expect(fake.lastWireBody, isNull);

    final older = await api.notifications.list(before: '88');
    expect(older.items.map((item) => item.id), ['n_20']);
    expect(older.nextBefore, isNull);

    final first = await api.notifications.markRead('88', requestId: 'r1');
    expect(first.unreadCount, 1);
    expect(first.notification?.notificationId, '88');
    expect(first.notification?.isRead, isTrue);
    expect(fake.lastWireBody, isNull);
    expect(fake.notificationMutationApplies, 1);
    final writes = api.notifications as RemoteNotificationsRepository;
    expect(writes.attemptedWriteRequestIds, ['r1']);

    final replay = await api.notifications.markRead('88', requestId: 'r1');
    expect(replay.unreadCount, 1);
    expect(fake.notificationMutationApplies, 1);
    expect(writes.attemptedWriteRequestIds, ['r1']);

    final again = await api.notifications.markRead('88', requestId: 'r2');
    expect(again.unreadCount, 1);
    expect(fake.notificationMutationApplies, 2);
    expect(await api.notifications.serverUnreadCount(), 1);

    final all = await api.notifications.markAllRead(requestId: 'all');
    expect(all.unreadCount, 0);
    expect(fake.lastWireBody, isNull);
    expect(await api.notifications.serverUnreadCount(), 0);
    expect(fake.notificationMutationApplies, 3);

    final allReplay = await api.notifications.markAllRead(requestId: 'all');
    expect(allReplay.unreadCount, 0);
    expect(fake.notificationMutationApplies, 3);

    final employee = await signedIn('employee.demo');
    expect(await employee.notifications.serverUnreadCount(), 1);
  });

  test('another user is not affected and the employee count starts at one', () async {
    final employee = await signedIn('employee.demo');
    expect(await employee.notifications.fetchUnreadCount(), 1);
    expect(
      (await employee.notifications.list()).items.map((item) => item.id),
      ['77'],
    );

    await employee.notifications.markRead('77');
    expect(await employee.notifications.serverUnreadCount(), 0);
    await employee.notifications.markRead('77');
    expect(await employee.notifications.serverUnreadCount(), 0);

    final other = await signedIn('other.employee');
    expect(await other.notifications.serverUnreadCount(), 2);
  });

  test('a 401 on the notification list forces logout', () async {
    final api = await signedIn('employee.demo');
    (api.client as FakeApiClient).expireSession();

    await expectLater(
      api.notifications.list(),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );

    await expectLater(
      api.notifications.serverUnreadCount(),
      throwsA(isA<SessionExpiredException>()),
    );
  });
}
