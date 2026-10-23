import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
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
      expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    },
  );

  testWidgets('retrying a failed reject sends the contract body again', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    fake.failMutationsRemaining = 1;

    final first = await hold(tester, fake, const Key('unlinked-reject-ur_1'));

    expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
    expect(first, {'decision': 'reject'});

    final second = await hold(tester, fake, const Key('unlinked-reject-ur_1'));

    expect(second, {'decision': 'reject'});
    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsNothing);
  });

  testWidgets(
    'a rejected receipt with pending cash shows no cash button and sends nothing',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      final postsBefore = fake.mutationPaths.length;

      expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('unlinked-card-ur_2')),
          matching: find.text(AppStrings.cashReceived),
        ),
        findsNothing,
      );
      expect(fake.mutationPaths, hasLength(postsBefore));
    },
  );

  testWidgets('cash on a rejected receipt is a status conflict', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('unlinked-card-ur_2')),
        matching: find.text(AppStrings.cashReceived),
      ),
      findsNothing,
    );

    // The button is hidden, so the screen cannot post. A direct cash call
    // on this rejected row is still a status conflict, with no body and no
    // change to the receipt.
    String? wire;
    await tester.runAsync(() async {
      await expectLater(
        layer.collections.markUnlinkedCashReceived('ur_2', MutationMeta()),
        throwsA(
          isA<ConflictException>()
              .having((error) => error.statusCode, 'status', 409)
              .having((error) => error.code, 'code', 'SUBMISSION_NOT_APPROVED')
              .having(
                (error) => error.message,
                'message',
                FakeApiClient.submissionNotApprovedMessage,
              ),
        ),
      );
      wire = fake.lastWireBody;
    });
    expect(wire, isNull);
    expect(
      fake.mutationPaths,
      contains('/api/collections/unlinked-receipts/ur_2/cash-received'),
    );

    final overview = await tester.runAsync(
      () => layer.client.get('/api/collections'),
    );
    final receipts = (overview!.data as Map)['unlinkedReceipts'] as List;
    final row = receipts.cast<Map>().firstWhere((item) => item['id'] == 'ur_2');
    expect(row['status'], 'rejected');
    expect(row['cashStatus'], 'pending');
    expect(row.containsKey('version'), isFalse);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
  });

  testWidgets(
    'a changed unlinked status refetches the overview and shows the conflict',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      final readsBefore = fake.collectionOverviewReads;
      expect(readsBefore, greaterThan(0));
      await tester.runAsync(
        () => layer.collections.decideUnlinked(
          'ur_1',
          decision: CollectionDecision.reject,
          meta: MutationMeta(),
        ),
      );

      final body = await hold(tester, fake, const Key('unlinked-reject-ur_1'));

      expect(
        find.text(FakeApiClient.submissionAlreadyDecidedMessage),
        findsWidgets,
      );
      expect(fake.collectionOverviewReads, greaterThan(readsBefore));
      expect(find.text('اسم غير مربوط تجريبي'), findsOneWidget);
      expect(find.byKey(const Key('unlinked-reject-ur_1')), findsNothing);
      expect(body, {'decision': 'reject'});
    },
  );

  testWidgets('unlinked actions stay RTL in both themes on a small phone', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(320, 640));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await reveal(tester, const Key('unlinked-reject-ur_1'));
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);

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
    await reveal(tester, const Key('unlinked-reject-ur_1'));

    final rejectDark = tester.element(
      find.byKey(const Key('unlinked-reject-ur_1')),
    );
    expect(Theme.of(rejectDark).brightness, Brightness.dark);
    expect(Directionality.of(rejectDark), TextDirection.rtl);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlinked actions do not overflow on a large phone', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(480, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await reveal(tester, const Key('unlinked-reject-ur_1'));
    final list = find.byKey(CollectionsScreen.screenKey);
    await tester.fling(list, const Offset(0, -600), 1200);
    await settle(tester);

    expect(find.byKey(const Key('unlinked-reject-ur_1')), findsOneWidget);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
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
Future<Map<String, dynamic>?> hold(
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
  final raw = fake.lastWireBody;
  final body = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
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
