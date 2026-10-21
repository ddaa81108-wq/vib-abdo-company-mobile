import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_open_seam.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_opener.dart'
    as gate;
import 'package:vib_abdo_company_mobile/notifications/system_tray_tap.dart';
import 'package:vib_abdo_company_mobile/state/notification_providers.dart';

import 'support/pump_app.dart';

void main() {
  AppNotification notice({required String id, String? recipient}) {
    return AppNotification(
      notificationId: id,
      systemName: 'VIB',
      employeeName: null,
      operationType: NotificationOperationType.collectionSubmit,
      operationTypeRaw: 'collection.submit',
      relatedRef: const NotificationRelatedRef(type: 'collections', id: 'sb_1'),
      createdAt: DateTime.utc(2026, 10, 18, 12),
      readAt: null,
      recipientUserId: recipient,
    );
  }

  Future<T> finish<T>(WidgetTester tester, Future<T> future) async {
    late T value;
    Object? error;
    StackTrace? stack;
    var done = false;
    future.then(
      (result) {
        value = result;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stack = s;
        done = true;
      },
    );
    for (var i = 0; i < 40 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    if (!done) fail('open did not finish');
    if (error != null) Error.throwWithStackTrace(error!, stack!);
    return value;
  }

  testWidgets(
    'a list tap and a tray tap both open through NotificationOpener',
    (tester) async {
      await pumpFakeApp(tester);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      final context = tester.element(find.byType(CompanyApp));
      final container = ProviderScope.containerOf(context);

      final listResult = await finish(
        tester,
        container
            .read(notificationOpenSeamProvider)
            .open(
              notice(id: 'n-list', recipient: null),
              origin: NotificationOpenOrigin.list,
            ),
      );
      expect(listResult.opened, isTrue);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);

      await finish(
        tester,
        container.read(notificationsProvider.notifier).ingest([
          notice(id: 'n-tray'),
        ], source: NotificationSource.fetch),
      );
      await finish(
        tester,
        container.read(systemTrayTapHandlerProvider).openPayload('n-tray'),
      );
      await tester.pump();
      expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);

      final forbidden = await finish(
        tester,
        container
            .read(notificationOpenSeamProvider)
            .open(
              notice(id: 'n-tray-2'),
              origin: NotificationOpenOrigin.systemTray,
            ),
      );
      expect(forbidden.forbidden, isTrue);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    },
  );

  testWidgets('a cold tray payload for the signed-in user opens collections', (
    tester,
  ) async {
    await pumpFakeApp(tester);
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    final context = tester.element(find.byType(CompanyApp));
    final container = ProviderScope.containerOf(context);
    await finish(
      tester,
      container.read(systemTrayTapHandlerProvider).openPayload('77'),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
  });

  testWidgets(
    'a list tap and a tray tap mark read once, and needsLogin does not',
    (tester) async {
      final layer = await pumpFakeApp(tester);
      final fake = layer.client as FakeApiClient;
      fake.stageNotification({
        'id': 'n-locked',
        'action': 'collection.submit',
        'section': 'collections',
        'entityId': 'sb_1',
        'readAt': null,
        'createdAt': '2026-10-18T11:00:00Z',
        'systemName': 'الاستلامات',
        'recipientUserId': 'u_12',
      });
      fake.stageNotification({
        'id': 'n-tray',
        'action': 'collection.submit',
        'section': 'collections',
        'entityId': 'sb_1',
        'readAt': null,
        'createdAt': '2026-10-18T11:30:00Z',
        'systemName': 'الاستلامات',
        'recipientUserId': 'u_12',
      }, unreadCount: 2);

      final context = tester.element(find.byType(CompanyApp));
      final container = ProviderScope.containerOf(context);
      final locked = notice(id: 'n-locked', recipient: 'u_12');
      final needsLogin = await finish(
        tester,
        container
            .read(notificationOpenSeamProvider)
            .open(locked, origin: NotificationOpenOrigin.list),
      );
      expect(needsLogin.needsLogin, isTrue);
      expect(fake.notificationMutationApplies, 0);
      container.read(gate.pendingNotificationOpenProvider).clear();

      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      final signedIn = tester.element(find.byType(CompanyApp));
      final signedInContainer = ProviderScope.containerOf(signedIn);
      await finish(
        tester,
        signedInContainer.read(notificationsProvider.notifier).refresh(),
      );
      expect(signedInContainer.read(unreadNotificationsCountProvider).value, 2);
      expect(_readAt(signedInContainer, 'n-locked'), isNull);
      expect(_readAt(signedInContainer, '77'), isNull);
      expect(_readAt(signedInContainer, 'n-tray'), isNull);

      final listNote = _row(signedInContainer, '77');
      final opened = await finish(
        tester,
        signedInContainer
            .read(notificationOpenSeamProvider)
            .open(listNote, origin: NotificationOpenOrigin.list),
      );
      expect(opened.opened, isTrue);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(signedInContainer.read(unreadNotificationsCountProvider).value, 1);
      expect(_readAt(signedInContainer, '77'), isNotNull);
      expect(_readAt(signedInContainer, 'n-tray'), isNull);
      expect(_readAt(signedInContainer, 'n-locked'), isNull);

      await finish(
        tester,
        signedInContainer
            .read(notificationOpenSeamProvider)
            .open(listNote, origin: NotificationOpenOrigin.list),
      );
      expect(signedInContainer.read(unreadNotificationsCountProvider).value, 1);

      await finish(
        tester,
        signedInContainer
            .read(systemTrayTapHandlerProvider)
            .openPayload('n-tray'),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(signedInContainer.read(unreadNotificationsCountProvider).value, 0);
      expect(_readAt(signedInContainer, 'n-tray'), isNotNull);
      expect(_readAt(signedInContainer, 'n-locked'), isNull);

      await finish(
        tester,
        signedInContainer
            .read(systemTrayTapHandlerProvider)
            .openPayload('n-tray'),
      );
      expect(signedInContainer.read(unreadNotificationsCountProvider).value, 0);
    },
  );
}

AppNotification _row(ProviderContainer container, String id) {
  final items =
      container.read(notificationsProvider).value?.appNotifications ??
      const <AppNotification>[];
  return items.firstWhere((item) => item.notificationId == id);
}

DateTime? _readAt(ProviderContainer container, String id) =>
    _row(container, id).readAt;
