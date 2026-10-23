import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('reject and cash stay hidden without the action permission', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.text('اسم غير مربوط تجريبي'), findsOneWidget);
    expect(find.text('استلام مرفوض تجريبي'), findsOneWidget);
    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    expect(find.byKey(const Key('unlinked-approve-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-actions-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-actions-ur_2')), findsNothing);
  });

  testWidgets('decide without cash receive shows reject and hides cash', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    expect(find.byKey(const Key('unlinked-cash-ur_1')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('unlinked-reject-ur_1')),
        matching: find.text(AppStrings.reject),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a pending receipt is not offered cash until the server says so',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 2400));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');

      expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
      expect(find.byKey(const Key('unlinked-cash-ur_1')), findsNothing);
      expect(find.byKey(const Key('unlinked-reject-ur_2')), findsNothing);
      expect(find.byKey(const Key('unlinked-cash-ur_2')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('unlinked-cash-ur_2')),
          matching: find.text(AppStrings.cashReceived),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'retrying an unchanged reject reuses the request id and version',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      fake.failMutationsRemaining = 1;

      final first = await hold(tester, fake, const Key('unlinked-reject-ur_1'));

      expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
      expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
      expect(first['expectedVersion'], 1);
      expect(first['decision'], 'reject');
      expect(fake.mutationRequestIds, [first['requestId']]);

      final second = await hold(
        tester,
        fake,
        const Key('unlinked-reject-ur_1'),
      );

      expect(second['requestId'], first['requestId']);
      expect(second['expectedVersion'], 1);
      expect(second['decision'], 'reject');
      expect(fake.mutationRequestIds, [first['requestId'], first['requestId']]);
    },
  );

  testWidgets('confirming cash on a rejected receipt sends its version', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    final body = await hold(tester, fake, const Key('unlinked-cash-ur_2'));

    expect(body['expectedVersion'], 4);
    expect(body.containsKey('decision'), isFalse);
    expect(body['requestId'], fake.mutationRequestIds.single);
    expect(find.textContaining(AppStrings.serverReply), findsWidgets);
  });

  testWidgets(
    'a version conflict refetches the overview and shows the message',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      final readsBefore = fake.collectionOverviewReads;
      expect(readsBefore, greaterThan(0));
      fake.versionConflictRemaining = 1;

      final body = await hold(tester, fake, const Key('unlinked-reject-ur_1'));

      expect(find.text(AppStrings.versionConflict), findsWidgets);
      expect(fake.collectionOverviewReads, greaterThan(readsBefore));
      expect(find.text('اسم غير مربوط تجريبي'), findsOneWidget);
      expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
      expect(body['expectedVersion'], 1);

      await hold(tester, fake, const Key('unlinked-reject-ur_1'));

      expect(fake.mutationRequestIds, hasLength(2));
      expect(fake.mutationRequestIds[0], fake.mutationRequestIds[1]);
    },
  );

  testWidgets('unlinked actions stay RTL in both themes on a small phone', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(320, 640));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await reveal(tester, const Key('unlinked-reject-ur_1'));
    await reveal(tester, const Key('unlinked-cash-ur_2'));

    expect(tester.takeException(), isNull);
    final reject = tester.element(
      find.byKey(const Key('unlinked-reject-ur_1')),
    );
    expect(Directionality.of(reject), TextDirection.rtl);
    expect(Theme.of(reject).brightness, Brightness.light);
    expect(
      tester.getRect(find.byKey(const Key('unlinked-reject-ur_1'))).right,
      greaterThan(320 / 2),
    );

    await go(tester, '/account');
    await tester.tap(find.byKey(const Key('theme-switch')));
    await settle(tester);
    expect(
      Theme.of(tester.element(find.byKey(const Key('theme-switch'))))
          .brightness,
      Brightness.dark,
    );
    await go(tester, '/collections');
    await reveal(tester, const Key('unlinked-cash-ur_2'));

    final cash = tester.element(find.byKey(const Key('unlinked-cash-ur_2')));
    expect(Theme.of(cash).brightness, Brightness.dark);
    expect(Directionality.of(cash), TextDirection.rtl);
    expect(
      find.descendant(
        of: find.byKey(const Key('unlinked-cash-ur_2')),
        matching: find.text(AppStrings.cashReceived),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlinked actions do not overflow on a large phone', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(480, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await reveal(tester, const Key('unlinked-reject-ur_1'));
    await reveal(tester, const Key('unlinked-cash-ur_2'));
    final list = find.byKey(CollectionsScreen.screenKey);
    await tester.fling(list, const Offset(0, -600), 1200);
    await settle(tester);

    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    400,
    scrollable: find.descendant(
      of: find.byKey(CollectionsScreen.screenKey),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump();
}

/// Sends one write and returns the body captured while that send is paused.
///
/// A later refresh is a GET and clears [FakeApiClient.lastWireBody], so the
/// body has to be read before the gate opens.
Future<Map<String, dynamic>> hold(
  WidgetTester tester,
  FakeApiClient fake,
  Key key,
) async {
  final gate = Completer<void>();
  fake.pauseMutations = gate;
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(Duration.zero);
  final body = jsonDecode(fake.lastWireBody!) as Map<String, dynamic>;
  gate.complete();
  fake.pauseMutations = null;
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
  return body;
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
