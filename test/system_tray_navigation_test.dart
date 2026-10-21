import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_open_seam.dart';
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
}
