import 'dart:async';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// P7-20 and P7-21 against the real repository and [FakeApiClient]'s store.
/// The request id comes from [MutationMeta] / [RequestIds], not a fixed literal.
void main() {
  test('P7-21 a repeated requestId leaves one ledger row', () async {
    final harness = await _open();
    try {
      final meta = MutationMeta(expectedVersion: 4);
      final request = _payment();
      await harness.layer.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        meta,
      );
      await harness.layer.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        meta,
      );
      expect(harness.fake.mutationRequestIds, [meta.requestId]);
      expect(await _partialRows(harness.layer), 1);
    } finally {
      await harness.layer.dispose();
    }
  });

  test('P7-21 two in-flight writes with one requestId apply once', () async {
    final harness = await _open();
    final gate = Completer<void>();
    harness.fake.pauseMutations = gate;
    try {
      final meta = MutationMeta(expectedVersion: 4);
      final request = _payment();
      final first = harness.layer.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        meta,
      );
      final second = harness.layer.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        meta,
      );
      await _untilRequestRecorded(harness.fake, meta.requestId);
      expect(harness.fake.mutationRequestIds, [meta.requestId]);
      gate.complete();
      harness.fake.pauseMutations = null;
      await Future.wait([first, second]);
      expect(await _partialRows(harness.layer), 1);
    } finally {
      await harness.layer.dispose();
    }
  });

  test('P7-20 a failed write then the same requestId stores one row', () async {
    final harness = await _open();
    try {
      harness.fake.failMutationsRemaining = 1;
      final meta = MutationMeta(expectedVersion: 4);
      final request = _payment();
      await expectLater(
        harness.layer.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          request,
          meta,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(await _partialRows(harness.layer), 0);
      await harness.layer.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        meta,
      );
      expect(harness.fake.mutationRequestIds, [meta.requestId, meta.requestId]);
      expect(await _partialRows(harness.layer), 1);
    } finally {
      await harness.layer.dispose();
    }
  });

  test('P7-20 a 409 does not apply the write or replace the row', () async {
    final harness = await _open();
    try {
      final meta = MutationMeta(expectedVersion: 1);
      await expectLater(
        harness.layer.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          _payment(),
          meta,
        ),
        throwsA(
          isA<ConflictException>().having(
            (error) => error.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      expect(await _partialRows(harness.layer), 0);
      expect(harness.fake.mutationRequestIds, [meta.requestId]);
    } finally {
      await harness.layer.dispose();
    }
  });
}

AccountTransactionRequest _payment() => AccountTransactionRequest.partialPayment(
  inputValue: 10,
  date: DateTime.utc(2026, 10, 21),
);

Future<void> _untilRequestRecorded(FakeApiClient fake, String requestId) async {
  for (var turn = 0; turn < 40; turn++) {
    if (fake.mutationRequestIds.contains(requestId)) {
      for (var extra = 0; extra < 8; extra++) {
        await Future<void>.delayed(Duration.zero);
      }
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('FakeApiClient did not record $requestId');
}

Future<int> _partialRows(ApiLayer layer) async {
  final page = await layer.accounts.ledger(AccountSection.customers, 'c_55');
  return page.page.items.where((item) => item.id.startsWith('tx_partial')).length;
}

Future<({ApiLayer layer, FakeApiClient fake})> _open() async {
  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  await layer.session.login(username: 'admin.demo', password: 'demo-only');
  return (layer: layer, fake: layer.client as FakeApiClient);
}
