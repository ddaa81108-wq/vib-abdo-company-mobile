import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vib_abdo_company_mobile/features/collections/collection_card_tone.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_strings.dart';
import 'package:vib_abdo_company_mobile/state/collection_request_journal.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

/// Step 3 of the 537f073 match: the server rules the collections screens
/// rely on, run on the fake (staging stays read-only for collections).
void main() {
  group('card tone matches collectionCardState.ts', () {
    CollectionAssignmentDto card({
      int? balance = 100,
      String? mode,
      String? status,
      String assignedAt = '2026-10-18T07:00:00.000Z',
      String? submissionAt,
      String? decisionAt,
      String? cashAt,
      String external = '2026-10-18T06:00:00.000Z',
      bool pending = false,
      int cashOutstanding = 0,
    }) => CollectionAssignmentDto.fromJson({
      'id': 'as_x',
      'customerId': 'c_x',
      'customerName': 'x',
      'balanceUnits': ?balance,
      'assignedAt': assignedAt,
      'latestMode': ?mode,
      'latestStatus': ?status,
      'latestSubmissionAt': ?submissionAt,
      'latestDecisionAt': ?decisionAt,
      'latestCashReceivedAt': ?cashAt,
      'externalFinancialUpdatedAt': external,
      'hasPending': pending ? 1 : 0,
      'cashOutstandingCount': cashOutstanding,
    });

    test('rejected without later admin movement', () {
      expect(
        collectionCardTone(
          card(
            status: 'rejected',
            mode: 'partial',
            submissionAt: '2026-10-18T08:00:00.000Z',
            decisionAt: '2026-10-18T09:00:00.000Z',
          ),
        ),
        CollectionTone.rejected,
      );
    });

    test('rejected then an admin movement falls through to the balance', () {
      expect(
        collectionCardTone(
          card(
            status: 'rejected',
            decisionAt: '2026-10-18T09:00:00.000Z',
            external: '2026-10-18T10:00:00.000Z',
          ),
        ),
        CollectionTone.base,
      );
    });

    test('negative balance is green', () {
      expect(collectionCardTone(card(balance: -5)), CollectionTone.green);
    });

    test('zero is red only when cash is in and nothing is open', () {
      final settled = card(
        balance: 0,
        mode: 'full',
        status: 'approved',
        cashAt: '2026-10-18T11:00:00.000Z',
      );
      expect(collectionCardTone(settled), CollectionTone.red);
      expect(
        collectionCardTone(
          card(balance: 0, cashAt: '2026-10-18T11:00:00.000Z', pending: true),
        ),
        CollectionTone.zero,
      );
      expect(
        collectionCardTone(
          card(
            balance: 0,
            cashAt: '2026-10-18T11:00:00.000Z',
            cashOutstanding: 1,
          ),
        ),
        CollectionTone.zero,
      );
      expect(
        collectionCardTone(
          card(
            balance: 0,
            cashAt: '2026-10-18T05:00:00.000Z',
            external: '2026-10-18T06:00:00.000Z',
          ),
        ),
        CollectionTone.zero,
      );
      expect(collectionCardTone(card(balance: 0)), CollectionTone.zero);
    });

    test('partial is yellow unless an admin moved the card after it', () {
      expect(
        collectionCardTone(
          card(mode: 'partial', submissionAt: '2026-10-18T08:00:00.000Z'),
        ),
        CollectionTone.yellow,
      );
      expect(
        collectionCardTone(
          card(
            mode: 'partial',
            submissionAt: '2026-10-18T08:00:00.000Z',
            external: '2026-10-18T09:00:00.000Z',
          ),
        ),
        CollectionTone.base,
      );
      expect(collectionCardTone(card(mode: 'full')), CollectionTone.base);
      expect(collectionCardTone(card()), CollectionTone.base);
    });

    test('a missing balance keeps the neutral base card', () {
      expect(collectionCardTone(card(balance: null)), CollectionTone.base);
    });
  });

  test(
    'the request journal survives an app restart (SharedPreferences)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      final saved = await first
          .read(collectionRequestJournalProvider.notifier)
          .begin(
            userId: 'u_1',
            slot: 'submit:as_1',
            fingerprint: 'full|320',
            knownSubmissionIds: const ['sb_0'],
          );
      first.dispose();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsCollectionAttemptStore.key), isNotNull);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final list = await second.read(collectionRequestJournalProvider.future);
      expect(list, hasLength(1));
      expect(list.single.requestId, saved.requestId);
      expect(list.single.fingerprint, 'full|320');
      expect(list.single.knownSubmissionIds, ['sb_0']);

      // Same inputs keep the same request id; other inputs are refused.
      final again = await second
          .read(collectionRequestJournalProvider.notifier)
          .begin(userId: 'u_1', slot: 'submit:as_1', fingerprint: 'full|320');
      expect(again.requestId, saved.requestId);
      await expectLater(
        second
            .read(collectionRequestJournalProvider.notifier)
            .begin(userId: 'u_1', slot: 'submit:as_1', fingerprint: 'full|10'),
        throwsStateError,
      );
      await second
          .read(collectionRequestJournalProvider.notifier)
          .settle('u_1', 'submit:as_1');
      expect(await second.read(collectionAttemptStoreProvider).load(), isEmpty);
    },
  );

  testWidgets('a full receipt sends the current balance as its amount', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    final before = await tester.runAsync(() => layer.collections.overview());
    final as1 = before!.assignments.firstWhere((row) => row.id == 'as_1');
    final balance = as1.balanceUnits!.asInt!;

    await _tapFull(tester, 'as_1');

    expect(_submitPosts(fake, 'as_1'), 1);
    final after = await tester.runAsync(() => layer.collections.overview());
    final sent = after!.submissions.where((row) => row.assignmentId == 'as_1');
    expect(sent, hasLength(1));
    expect(sent.single.mode, 'full');
    expect(sent.single.amountUnits?.asInt, balance);
    expect(find.byKey(const Key('unconfirmed-as_1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lost reply is retried without a second receipt', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');

    // The server records the receipt, then the reply never arrives.
    fake.loseCollectionRepliesRemaining = 1;
    await _tapFull(tester, 'as_1');
    expect(_submitPosts(fake, 'as_1'), 1);
    expect(find.byKey(const Key('unconfirmed-as_1')), findsOneWidget);
    expect(find.byKey(const Key('retry-as_1')), findsOneWidget);

    final retry = find.byKey(const Key('retry-as_1'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await settle(tester);

    // No second POST: the retry read the overview and found the receipt.
    expect(_submitPosts(fake, 'as_1'), 1);
    expect(find.text(CollectionsText.alreadyRecorded), findsWidgets);
    expect(find.byKey(const Key('unconfirmed-as_1')), findsNothing);
    final after = await tester.runAsync(() => layer.collections.overview());
    expect(
      after!.submissions.where((row) => row.assignmentId == 'as_1'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('close is refused while the batch is not settled', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 3200));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    final close = find.byKey(const Key('close-batch'));
    await tester.ensureVisible(close);
    await tester.tap(close);
    await _pumpDialog(tester);
    final confirm = find.byKey(const Key('confirm-mutation'));
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await settle(tester);
    }

    expect(
      fake.mutationPaths.where(
        (p) => p.contains('/api/collections/days/close'),
      ),
      hasLength(1),
    );
    expect(
      find.textContaining('لا يمكن مسح اليوم قبل اعتماد جميع العمليات'),
      findsWidgets,
    );
    final after = await tester.runAsync(() => layer.collections.overview());
    expect(after!.assignments, isNotEmpty);
    expect(find.byKey(const Key('close-batch')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an admin sees payroll entries but cannot confirm them', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 3200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await pumpUntilFound(tester, find.byKey(const Key('payroll-entry-pe_1')));
    expect(find.byKey(const Key('payroll-confirm-pe_1')), findsNothing);
    expect(find.byKey(const Key('payroll-awaiting-pe_1')), findsOneWidget);
    // The server refuses an admin confirm (403) as well.
    await tester.runAsync(() async {
      await expectLater(
        layer.collections.confirmPayrollEntry('pe_1', MutationMeta()),
        throwsA(isA<ForbiddenException>()),
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('the employee confirms only their own payroll entry', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 3200));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    final confirm = find.byKey(const Key('payroll-confirm-pe_1'));
    await pumpUntilFound(tester, confirm);
    expect(find.byKey(const Key('payroll-entry-pe_9')), findsNothing);
    await tester.runAsync(() async {
      await expectLater(
        layer.collections.confirmPayrollEntry('pe_9', MutationMeta()),
        throwsA(isA<ForbiddenException>()),
      );
    });
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await _pumpDialog(tester);
    final sure = find.byKey(const Key('confirm-mutation'));
    if (sure.evaluate().isNotEmpty) {
      await tester.tap(sure);
      await settle(tester);
    }

    expect(fake.mutationPaths.where((p) => p.contains('pe_1')), hasLength(1));
    expect(find.byKey(const Key('payroll-confirm-pe_1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a standalone receipt links only to a card the server offered', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(430, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    final link = find.byKey(const Key('unlinked-link-ur_1'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await settle(tester);

    // The field is a search box, never an id box.
    await tester.enterText(find.byKey(const Key('link-customer')), 'c_55');
    final save = find.byKey(const Key('save-link'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    expect(fake.mutationPaths.where((p) => p.contains('ur_1')), isEmpty);
    expect(find.text(CollectionsText.chooseCard), findsWidgets);
    expect(find.byKey(const Key('link-form')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('awaiting cash uses the website words for each role', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 3200));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    final label = find.byKey(const ValueKey('awaiting-cash-sb_2'));
    await pumpUntilFound(tester, label);
    expect(
      find.descendant(
        of: label,
        matching: find.text('ينتظر استلام النقدية من الإدارة'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapFull(WidgetTester tester, String id) async {
  final full = find.byKey(Key('full-$id'));
  await tester.ensureVisible(full);
  await tester.tap(full);
  await _pumpDialog(tester);
  final confirm = find.byKey(const Key('confirm-mutation'));
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await settle(tester);
  }
}

int _submitPosts(FakeApiClient fake, String id) => fake.mutationPaths
    .where((p) => p == '/api/collections/assignments/$id/submissions')
    .length;

/// A guarded button keeps its spinner while its confirm dialog is open, so
/// the tree never goes idle until the dialog closes.
Future<void> _pumpDialog(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
