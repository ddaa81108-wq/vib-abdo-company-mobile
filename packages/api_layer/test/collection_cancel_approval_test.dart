import 'dart:convert';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel-approval posts the website body and the server row wins',
      () async {
    final api = await _login('admin.demo');
    final fake = api.client as FakeApiClient;
    final before = await api.collections.overview();
    final row = before.submissions.singleWhere((item) => item.id == 'sb_2');
    expect(row.approvedTransactionId, 'tx-sb_2');
    expect(row.awaitingCash, isTrue);

    final ack = await api.collections.cancelApproval(
      'sb_2',
      reason: 'تصحيح خاطئ',
      expectedTransactionId: 'tx-sb_2',
      meta: MutationMeta(requestId: 'cancel-sb-2'),
    );
    expect(ack.raw['cancelled'], true);
    final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
    expect(body['requestId'], 'cancel-sb-2');
    expect(body['reason'], 'تصحيح خاطئ');
    expect(body['expectedTransactionId'], 'tx-sb_2');
    expect(fake.mutationPaths.last,
        '/api/collections/submissions/sb_2/cancel-approval');

    final after = await api.collections.overview();
    final cancelled =
        after.submissions.singleWhere((item) => item.id == 'sb_2');
    expect(cancelled.status, 'rejected');
    expect(cancelled.awaitingCash, isFalse);

    final replay = await api.collections.cancelApproval(
      'sb_2',
      reason: 'تصحيح خاطئ',
      expectedTransactionId: 'tx-sb_2',
      meta: MutationMeta(requestId: 'cancel-sb-2'),
    );
    expect(replay.replayed, isTrue);
  });

  test('a short reason and an employee are refused', () async {
    final admin = await _login('admin.demo');
    expect(
      () => admin.collections.cancelApproval(
        'sb_2',
        reason: 'لا',
        expectedTransactionId: 'tx-sb_2',
        meta: MutationMeta(requestId: 'cancel-short'),
      ),
      throwsA(isA<ApiException>()),
    );

    final employee = await _login('employee.demo');
    expect(
      () => employee.collections.cancelApproval(
        'sb_2',
        reason: 'تصحيح خاطئ',
        expectedTransactionId: 'tx-sb_2',
        meta: MutationMeta(requestId: 'cancel-employee'),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('workspace receipts carry the approval transaction id', () async {
    final api = await _login('admin.demo');
    final overview = await api.collections.overview();
    final page = await api.collections.workspaceReceipts(
      batchId: overview.openBatches.first.id,
    );
    final row = page.items.singleWhere((item) => item['id'] == 'sb_2');
    expect(row['approvedTransactionId'], 'tx-sb_2');
    expect(page.hasMore, isFalse);
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
