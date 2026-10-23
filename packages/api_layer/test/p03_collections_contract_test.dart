import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// P-03. The collections sample has no `version`, and decision / cash-received
/// bodies match openapi.json. Only the fake transport stands in for the server.
void main() {
  test('GET /api/collections sample parses without version', () {
    final file = _samplesFile();
    final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final sample = root['GET /api/collections'] as Map<String, dynamic>;
    expect(sample['status'], 200);
    final body = sample['body'] as Map<String, dynamic>;
    expect(body['ok'], true);
    final data = body['data'] as Map<String, dynamic>;

    final overview = CollectionsOverviewDto.fromData(data);

    expect(overview.submissions, hasLength(2));
    expect(overview.unlinkedReceipts, hasLength(1));
    expect(overview.assignments, hasLength(1));

    final pending = overview.submissions[0];
    final approved = overview.submissions[1];
    final receipt = overview.unlinkedReceipts.single;

    expect(pending.id, 'd37f68dd-814d-4a9b-908b-278e1a259b2f');
    expect(pending.status, 'pending');
    expect(pending.mode, 'partial');
    expect(pending.amountUnits?.units, 50);
    expect(pending.version, isNull);
    expect(pending.raw.containsKey('version'), isFalse);
    expect(pending.cashReceivedAt, isNull);

    expect(approved.id, 'ec6a801b-377e-4fb5-9aca-aa8efdb252ea');
    expect(approved.status, 'approved');
    expect(approved.amountUnits?.units, 100);
    expect(approved.version, isNull);
    expect(approved.raw.containsKey('version'), isFalse);

    expect(receipt.id, 'ef293fb5-7a04-4e24-8624-3e02fd9c8115');
    expect(receipt.customerName, 'استلام مستقل للاختبار');
    expect(receipt.status, 'pending');
    expect(receipt.amountUnits?.units, 75);
    expect(receipt.version, isNull);
    expect(receipt.raw.containsKey('version'), isFalse);

    expect(overview.collectedUnits?.units, 100);
    expect(overview.pendingCount, 1);
    expect(overview.unlinkedPendingCount, 1);
    expect(overview.cashOutstandingUnits?.units, 100);
    expect(overview.assignedCount, 1);
    expect(overview.assignments.single.balanceUnits?.units, 300);
    expect(
      overview.employeeTotals.map((row) => row.employeeName),
      containsAll(['محصل الاختبار', 'مشرف اختبار محدود']),
    );
  });

  test('approve, reject, and cash use the contract bodies', () async {
    final api = await _login();
    final fake = api.client as FakeApiClient;

    final approved = await api.collections.decide(
      'sb_1',
      CollectionDecision.approve,
      note: 'مطابقة اختبار',
      meta: MutationMeta(requestId: 'not-sent', expectedVersion: 9),
    );
    expect(jsonDecode(fake.lastWireBody!), {
      'decision': 'approve',
      'note': 'مطابقة اختبار',
    });
    expect(approved.id, 'sb_1');
    expect(approved.version, isNull);
    expect(approved.raw['status'], 'approved');
    expect(approved.raw['transactionId'], 'collection-sb_1');
    // sb_1 is not linked to a card. The amount is not a balance.
    expect(approved.balanceUnits, isNull);
    expect(approved.raw.containsKey('balanceUnits'), isFalse);
    expect(approved.raw['eventSequences'], [3]);
    expect(approved.raw.containsKey('version'), isFalse);

    final rejected = await api.collections.decide(
      'sb_9',
      CollectionDecision.reject,
      meta: MutationMeta(requestId: 'also-not-sent', expectedVersion: 1),
    );
    expect(jsonDecode(fake.lastWireBody!), {'decision': 'reject'});
    expect(rejected.raw['status'], 'rejected');
    expect(rejected.raw.containsKey('transactionId'), isFalse);
    expect(rejected.raw.containsKey('balanceUnits'), isFalse);
    expect(rejected.raw.containsKey('version'), isFalse);
    expect(rejected.version, isNull);

    final cash = await api.collections.markCashReceived(
      'sb_2',
      MutationMeta(requestId: 'cash-not-sent', expectedVersion: 3),
    );
    expect(fake.lastWireBody, isNull);
    expect(cash.raw['id'], 'sb_2');
    expect(cash.raw['cashReceivedAt'], '2026-10-22T22:00:00.000Z');
    expect(cash.raw['eventSequences'], [4]);
    expect(cash.version, isNull);

    final linked = await api.collections.decideUnlinked(
      'ur_1',
      decision: CollectionDecision.approve,
      customerId: 'c_55',
      entryType: 'payment',
      note: 'مطابقة اختبار',
      newAccountKind: 'customer',
      meta: MutationMeta(requestId: 'ulink-not-sent', expectedVersion: 4),
    );
    expect(jsonDecode(fake.lastWireBody!), {
      'decision': 'approve',
      'customerId': 'c_55',
      'entryType': 'payment',
      'note': 'مطابقة اختبار',
      'newAccountKind': 'customer',
    });
    expect(linked.raw['status'], 'approved');
    // ur_1 is 50 against customer c_55's stored 320. The ack is that balance.
    expect(linked.balanceUnits?.units, 270);
    expect(linked.raw['balanceUnits'], 270);
    expect(linked.raw.containsKey('version'), isFalse);
    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(card.balanceUnits?.units, 270);

    final unlinkedCash = await api.collections.markUnlinkedCashReceived(
      'ur_1',
      MutationMeta(requestId: 'ucash-not-sent', expectedVersion: 2),
    );
    expect(fake.lastWireBody, isNull);
    expect(unlinkedCash.raw['cashReceivedAt'], '2026-10-22T22:00:00.000Z');
    expect(unlinkedCash.version, isNull);

    final overview = await api.collections.overview();
    expect(
      overview.submissions.map((row) => row.version),
      everyElement(isNull),
    );
    expect(
      overview.unlinkedReceipts.map((row) => row.version),
      everyElement(isNull),
    );
    expect(
      overview.submissions.firstWhere((row) => row.id == 'sb_1').status,
      'approved',
    );
    expect(
      overview.submissions.firstWhere((row) => row.id == 'sb_9').status,
      'rejected',
    );
    expect(
      overview.submissions.firstWhere((row) => row.id == 'sb_2').cashStatus,
      CashStatus.received,
    );
    expect(
      overview.unlinkedReceipts.firstWhere((row) => row.id == 'ur_1').status,
      'approved',
    );
  });

  test('a decision on a changed status is a 409 conflict', () async {
    final api = await _login();
    await api.collections.decide(
      'sb_1',
      CollectionDecision.approve,
      meta: MutationMeta(),
    );

    await expectLater(
      api.collections.decide(
        'sb_1',
        CollectionDecision.reject,
        meta: MutationMeta(expectedVersion: 1, requestId: 'stale'),
      ),
      throwsA(
        isA<ConflictException>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.code, 'code', 'SUBMISSION_ALREADY_DECIDED')
            .having(
              (error) => error.message,
              'message',
              FakeApiClient.submissionAlreadyDecidedMessage,
            ),
      ),
    );

    final overview = await api.collections.overview();
    final row = overview.submissions.firstWhere((item) => item.id == 'sb_1');
    expect(row.status, 'approved');
    expect(row.version, isNull);

    await expectLater(
      api.collections.markCashReceived('sb_9', MutationMeta()),
      throwsA(
        isA<ConflictException>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.code, 'code', 'SUBMISSION_NOT_APPROVED'),
      ),
    );
    final stillPending = (await api.collections.overview())
        .submissions
        .firstWhere((item) => item.id == 'sb_9');
    expect(stillPending.status, 'pending');
    expect(stillPending.cashStatus, CashStatus.notApplicable);
  });
}

File _samplesFile() {
  const relative = 'docs/api/evidence/api-samples.json';
  final fromPackage = File('../../$relative');
  if (fromPackage.existsSync()) return fromPackage;
  final fromRoot = File(relative);
  if (fromRoot.existsSync()) return fromRoot;
  throw StateError('api-samples.json not found from ${Directory.current.path}');
}

Future<ApiLayer> _login() async {
  final api = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(api.dispose);
  await api.session.login(username: 'admin.demo', password: 'x');
  return api;
}
