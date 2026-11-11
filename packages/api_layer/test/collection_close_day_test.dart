import 'dart:convert';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a settled batch closes and leaves no open batch', () async {
    final api = await _login('admin.demo');
    final fake = api.client as FakeApiClient;
    await api.collections.decide(
      'sb_1',
      CollectionDecision.approve,
      meta: MutationMeta(requestId: 'close-approve-sb1'),
    );
    await api.collections.markCashReceived(
      'sb_1',
      MutationMeta(requestId: 'close-cash-sb1'),
    );
    await api.collections.markCashReceived(
      'sb_2',
      MutationMeta(requestId: 'close-cash-sb2'),
    );
    await api.collections.decide(
      'sb_9',
      CollectionDecision.reject,
      meta: MutationMeta(requestId: 'close-reject-sb9'),
    );
    await api.collections.decideUnlinked(
      'ur_1',
      decision: CollectionDecision.reject,
      meta: MutationMeta(requestId: 'close-reject-ur1'),
    );
    await api.collections.decideUnlinked(
      'ur_9',
      decision: CollectionDecision.reject,
      meta: MutationMeta(requestId: 'close-reject-ur9'),
    );
    final before = await api.collections.overview();
    final batch = before.openBatches.single;
    expect(batch.pendingCount, 0);
    expect(batch.cashPendingCount, 0);

    final ack = await api.collections.closeDay(
      batchId: batch.id,
      meta: MutationMeta(requestId: 'close-b1'),
    );
    expect(ack.raw['closed'], true);
    final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
    expect(body['batchId'], batch.id);
    expect(body['confirmed'], true);

    final after = await api.collections.overview();
    expect(after.openBatches, isEmpty);
    expect(after.assignments, isEmpty);
  });

  test('outstanding cash needs the exceptional close body', () async {
    final api = await _login('admin.demo');
    await api.collections.decide(
      'sb_1',
      CollectionDecision.reject,
      meta: MutationMeta(requestId: 'ex-reject-sb1'),
    );
    await api.collections.decide(
      'sb_9',
      CollectionDecision.reject,
      meta: MutationMeta(requestId: 'ex-reject-sb9'),
    );
    await api.collections.decideUnlinked(
      'ur_1',
      decision: CollectionDecision.reject,
      meta: MutationMeta(requestId: 'ex-reject-ur1'),
    );
    await api.collections.decideUnlinked(
      'ur_9',
      decision: CollectionDecision.reject,
      meta: MutationMeta(requestId: 'ex-reject-ur9'),
    );
    final open = await api.collections.overview();
    final batch = open.openBatches.single;
    expect(batch.pendingCount, 0);
    expect(batch.cashPendingCount, greaterThan(0));

    await expectLater(
      api.collections.closeDay(
        batchId: batch.id,
        meta: MutationMeta(requestId: 'ex-plain'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.code,
          'code',
          'COLLECTION_DAY_NOT_SETTLED',
        ),
      ),
    );

    final ack = await api.collections.closeDay(
      batchId: batch.id,
      meta: MutationMeta(requestId: 'ex-close'),
      allowOutstandingCash: true,
      reason: 'إغلاق مع نقدية',
      expectedCashPendingCount: batch.cashPendingCount,
      expectedCashPendingUnits: batch.cashPendingUnits,
    );
    expect(ack.raw['closed'], true);
    expect(ack.raw['archived'], true);
  });

  test('any admin role may close and an employee may not', () async {
    final limited = await _login('limited.admin.demo');
    await expectLater(
      limited.collections.closeDay(
        batchId: 'b_1',
        meta: MutationMeta(requestId: 'limited-close'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.message,
          'message',
          'لا يمكن مسح اليوم قبل اعتماد جميع العمليات واستلام كل النقدية.',
        ),
      ),
    );

    final employee = await _login('employee.demo');
    await expectLater(
      employee.collections.closeDay(
        batchId: 'b_1',
        meta: MutationMeta(requestId: 'employee-close'),
      ),
      throwsA(isA<ForbiddenException>()),
    );
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
