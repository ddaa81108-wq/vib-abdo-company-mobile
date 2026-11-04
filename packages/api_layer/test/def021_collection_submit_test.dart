import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DEF-021 assignment submit and unlinked submit are on the next overview',
      () async {
    final api = await _login('employee.demo');
    final before = await api.collections.overview();
    expect(before.submissions.map((row) => row.id), ['sb_1', 'sb_2']);
    // 537f073 does not list rejected unlinked receipts.
    expect(before.unlinkedReceipts.map((row) => row.id), ['ur_1']);
    expect(before.pendingCount, 1);
    expect(before.unlinkedPendingCount, 1);
    expect(before.collectedUnits?.units, 250);
    expect(before.dayTotalUnits, isNull);

    final submission = await api.collections.submit(
      'as_1',
      mode: 'partial',
      amountUnits: 40,
      meta: MutationMeta(requestId: 'submit-as-1'),
    );
    expect(submission.id, startsWith('sb_posted_'));

    // One pending submission per card: a second send is refused, so a
    // resend after a lost reply cannot add a second pending receipt.
    await expectLater(
      api.collections.submit(
        'as_1',
        mode: 'partial',
        amountUnits: 40,
        meta: MutationMeta(requestId: 'submit-as-1'),
      ),
      throwsA(isA<PendingSubmissionExistsException>()),
    );

    final receipt = await api.collections.createUnlinkedReceipt(
      customerName: 'زبون جديد',
      amountUnits: 25,
      meta: MutationMeta(requestId: 'unlinked-new'),
    );
    expect(receipt.id, startsWith('ur_posted_'));
    final replay = await api.collections.createUnlinkedReceipt(
      customerName: 'زبون جديد',
      amountUnits: 25,
      meta: MutationMeta(requestId: 'unlinked-new'),
    );
    expect(replay.id, receipt.id);

    await expectLater(
      api.collections.submit(
        'as_9',
        mode: 'partial',
        amountUnits: 1,
        meta: MutationMeta(requestId: 'other-assignment'),
      ),
      throwsA(isA<ForbiddenException>()),
    );

    final overview = await api.collections.overview();
    expect(overview.submissions.first.id, submission.id);
    expect(overview.submissions, hasLength(3));
    final created = overview.unlinkedReceipts
        .singleWhere((row) => row.id == receipt.id);
    expect(created.customerName, 'زبون جديد');
    expect(created.amountUnits?.units, 25);
    expect(created.status, 'pending');
    expect(created.collectorName, 'موظف استلام تجريبي');
    final stored = overview.submissions.first;
    expect(stored.mode, 'partial');
    expect(stored.amountUnits?.units, 40);
    expect(stored.status, 'pending');
    expect(stored.assignmentId, 'as_1');
    expect(stored.submittedByName, 'موظف استلام تجريبي');
    expect(stored.awaitingCash, isFalse);
    // Server-computed figures follow the rows.
    expect(overview.pendingCount, 2);
    expect(overview.unlinkedPendingCount, 2);
    expect(overview.collectedUnits?.units, 250);
    final card = overview.assignments.singleWhere((row) => row.id == 'as_1');
    expect(card.status, 'active');
    expect(card.hasPending, isTrue);
    expect(card.latestMode, 'partial');
  });

  test('a stored submission can be approved', () async {
    final api = await _login('admin.demo');
    final ack = await api.collections.submit(
      'as_1',
      mode: 'partial',
      amountUnits: 40,
      meta: MutationMeta(requestId: 'admin-submit'),
    );
    final decided = await api.collections.decide(
      ack.id!,
      CollectionDecision.approve,
      meta: MutationMeta(requestId: 'admin-decide'),
    );
    expect(decided.version, isNull);
    expect(decided.raw['status'], 'approved');
    final overview = await api.collections.overview();
    final row = overview.submissions.singleWhere((item) => item.id == ack.id);
    expect(row.status, 'approved');
    expect(row.version, isNull);
    expect(row.amountUnits?.units, 40);
  });
}

Future<ApiLayer> _login(String username) async {
  final api = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(api.dispose);
  await api.session.login(username: username, password: 'x');
  return api;
}
