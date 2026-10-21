import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notification_opener.dart';
import 'package:vib_abdo_company_mobile/features/notifications/notifications_screen.dart';
import 'package:vib_abdo_company_mobile/state/router_provider.dart';

import 'support/pump_app.dart';

void main() {
  AppNotification notice({
    required String id,
    NotificationRelatedRef? ref,
    String? recipient,
    NotificationOperationType type = NotificationOperationType.collectionSubmit,
    String raw = 'collection.submit',
  }) {
    return AppNotification(
      notificationId: id,
      systemName: 'VIB',
      employeeName: null,
      operationType: type,
      operationTypeRaw: raw,
      relatedRef: ref,
      createdAt: DateTime.utc(2026, 10, 18, 12),
      readAt: null,
      recipientUserId: recipient,
    );
  }

  Future<NotificationOpener> openerOf(WidgetTester tester) async {
    final context = tester.element(find.byType(CompanyApp));
    return ProviderScope.containerOf(context).read(notificationOpenerProvider);
  }

  /// The fake client waits on [Future.delayed], even for a zero latency.
  /// Awaiting that future directly never reaches [WidgetTester.pump].
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
    if (!done) fail('opener did not finish');
    if (error != null) Error.throwWithStackTrace(error!, stack!);
    return value;
  }

  String pathOf(WidgetTester tester) {
    final context = tester.element(find.byType(CompanyApp));
    return ProviderScope.containerOf(context)
        .read(routerProvider)
        .state
        .uri
        .path;
  }

  test('related ref mapping', () {
    expect(
      resolveNotificationTarget(
        const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
      )?.location,
      '/collections',
    );
    expect(
      resolveNotificationTarget(
        const NotificationRelatedRef(type: 'receipt', id: 'ur_1'),
      )?.location,
      '/collections',
    );
    expect(
      resolveNotificationTarget(
        const NotificationRelatedRef(type: 'customers', id: 'c_59'),
      )?.location,
      '/customers/c_59',
    );
    expect(
      resolveNotificationTarget(
        const NotificationRelatedRef(type: 'account', id: 'c_59'),
      ),
      isNull,
    );
    expect(resolveNotificationTarget(null), isNull);
  });

  testWidgets('opener routes for each result', (tester) async {
    await pumpFakeApp(tester);
    final opener = await openerOf(tester);

    final needsLogin = await finish(
      tester,
      opener.open(
        notice(
          id: '77',
          recipient: 'u_12',
          ref: const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
        ),
        origin: NotificationOpenOrigin.systemTray,
      ),
    );
    expect(needsLogin, NotificationOpenResult.needsLogin);
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);

    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    // Zero-latency fake calls still sit on a timer. Flush them so the host's
    // cold-start resume can navigate before this test resumes the same tap.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    final resumed = await finish(
      tester,
      (await openerOf(tester)).resumePending(),
    );
    if (resumed != null) {
      expect(resumed, NotificationOpenResult.opened);
    }
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);

    final signedInOpener = await openerOf(tester);
    final forbidden = await finish(
      tester,
      signedInOpener.open(
        notice(
          id: '77',
          recipient: 'u_12',
          ref: const NotificationRelatedRef(type: 'companies', id: 'co_1'),
        ),
        origin: NotificationOpenOrigin.list,
      ),
    );
    expect(forbidden, NotificationOpenResult.forbidden);
    await tester.pumpAndSettle();
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);

    final wrongUser = await finish(
      tester,
      signedInOpener.open(
        notice(
          id: '88',
          recipient: 'u_20',
          ref: const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
        ),
        origin: NotificationOpenOrigin.banner,
      ),
    );
    expect(wrongUser, NotificationOpenResult.forbidden);

    final missingRecipient = await finish(
      tester,
      signedInOpener.open(
        notice(
          id: '77',
          ref: const NotificationRelatedRef(type: 'collection', id: 'sb_1'),
        ),
        origin: NotificationOpenOrigin.systemTray,
      ),
    );
    expect(missingRecipient, NotificationOpenResult.forbidden);

    final noTarget = await finish(
      tester,
      signedInOpener.open(
        notice(
          id: '77',
          recipient: 'u_12',
          ref: const NotificationRelatedRef(type: 'account', id: 'c_59'),
        ),
        origin: NotificationOpenOrigin.list,
      ),
    );
    expect(noTarget, NotificationOpenResult.noTarget);
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationsScreen.screenKey), findsOneWidget);
    expect(pathOf(tester), '/notifications');

    final notFound = await finish(
      tester,
      signedInOpener.open(
        notice(
          id: '77',
          recipient: 'u_12',
          ref: const NotificationRelatedRef(type: 'customers', id: 'missing'),
        ),
        origin: NotificationOpenOrigin.list,
      ),
    );
    expect(notFound, NotificationOpenResult.notFound);
    expect(pathOf(tester), '/notifications');

    final opened = await finish(
      tester,
      signedInOpener.open(
        notice(
          id: '77',
          recipient: 'u_12',
          ref: const NotificationRelatedRef(type: 'receipt', id: 'ur_1'),
        ),
        origin: NotificationOpenOrigin.list,
      ),
    );
    expect(opened, NotificationOpenResult.opened);
    await tester.pumpAndSettle();
    expect(find.byKey(CollectionsScreen.screenKey), findsOneWidget);
    expect(pathOf(tester), '/collections');
  });
}
