import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DEF-021 assignment submit and unlinked submit are on the next overview',
      () async {
    final api = await _login('employee.demo');
    final before = await api.collections.overview();
    expect(before.submissions.map((row) => row.id), ['sb_1', 'sb_2']);
    expect(before.unlinkedReceipts.map((row) => row.id), ['ur_1', 'ur_2']);
    expect(before.pendingCount, 1);
    expect(before.unlinkedPendingCount, 1);
    expect(before.dayTotalUnits?.units, 40);

    final submission = await api.collections.submit(
      'as_1',
      mode: 'partial',
      amountUnits: 40,
      meta: MutationMeta(requestId: 'submit-as-1'),
    );
    expect(submission.id, 'sb_posted_1');
    expect(submission.version, 1);

    final replay = await api.collections.submit(
      'as_1',
      mode: 'partial',
      amountUnits: 99,
      meta: MutationMeta(requestId: 'submit-as-1'),
    );
    expect(replay.id, submission.id);

    final receipt = await api.collections.createUnlinkedReceipt(
      customerName: 'زبون جديد',
      amountUnits: 25,
      meta: MutationMeta(requestId: 'unlinked-new'),
    );
    expect(receipt.id, 'ur_posted_1');
    expect(receipt.version, 1);

    await expectLater(
      api.collections.submit(
        'as_9',
        mode: 'partial',
        amountUnits: 1,
        meta: MutationMeta(requestId: 'other-assignment'),
      ),
      throwsA(isA<NotFoundException>()),
    );

    final overview = await api.collections.overview();
    expect(overview.submissions.map((row) => row.id), [
      'sb_1',
      'sb_2',
      'sb_posted_1',
    ]);
    expect(overview.unlinkedReceipts.map((row) => row.id), [
      'ur_1',
      'ur_2',
      'ur_posted_1',
    ]);
    final stored = overview.submissions.last;
    expect(stored.mode, 'partial');
    expect(stored.amountUnits?.units, 40);
    expect(stored.status, 'pending');
    expect(stored.version, isNull);
    expect(stored.cashStatus, isNull);
    expect(stored.submittedByName, 'موظف استلام تجريبي');
    final created = overview.unlinkedReceipts.last;
    expect(created.customerName, 'زبون جديد');
    expect(created.amountUnits?.units, 25);
    expect(created.status, 'pending');
    expect(created.version, isNull);
    expect(created.cashStatus, isNull);
    // Stored literals. The new rows are not summed into these figures.
    expect(overview.pendingCount, before.pendingCount);
    expect(overview.unlinkedPendingCount, before.unlinkedPendingCount);
    expect(overview.dayTotalUnits, before.dayTotalUnits);
    expect(
      overview.assignments.singleWhere((row) => row.id == 'as_1').status,
      'open',
    );
  });

  test('a stored submission can be approved by its version', () async {
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
      meta:
          MutationMeta(expectedVersion: ack.version, requestId: 'admin-decide'),
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
