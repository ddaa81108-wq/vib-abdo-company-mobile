import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DEF-015 cash in and cash out are returned by the ledger', () async {
    final api = await _admin();
    final fake = api.client as FakeApiClient;
    final before = await api.treasury.summary();
    expect(before.version, 7);
    expect(before.activeCashUnits, 8000);
    expect(before.netUnits, 51000);

    final cashIn = await api.treasury.addCashEntry(
      const CashEntryRequest(
        direction: CashDirection.cashIn,
        amountUnits: 1250,
        description: 'قبض',
      ),
      MutationMeta(expectedVersion: 7, requestId: 'cash-in-1'),
    );
    expect(cashIn.id, 'ce_8');
    expect(cashIn.version, 8);

    final replay = await api.treasury.addCashEntry(
      const CashEntryRequest(
        direction: CashDirection.cashIn,
        amountUnits: 9999,
        description: 'مكرر',
      ),
      MutationMeta(expectedVersion: 7, requestId: 'cash-in-1'),
    );
    expect(replay.id, cashIn.id);
    expect(replay.version, 8);
    expect(fake.mutationRequestIds.where((id) => id == 'cash-in-1'), [
      'cash-in-1',
    ]);

    await expectLater(
      api.treasury.addCashEntry(
        const CashEntryRequest(
          direction: CashDirection.cashOut,
          amountUnits: 200,
          description: 'صرف قديم',
        ),
        MutationMeta(expectedVersion: 7, requestId: 'cash-out-stale'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );

    final cashOut = await api.treasury.addCashEntry(
      const CashEntryRequest(
        direction: CashDirection.cashOut,
        amountUnits: 200,
        description: 'صرف',
      ),
      MutationMeta(expectedVersion: 8, requestId: 'cash-out-1'),
    );
    expect(cashOut.id, 'ce_9');
    expect(cashOut.version, 9);

    final ledger = await api.treasury.cashLedger();
    expect(ledger.items.map((entry) => entry.id), ['ce_9', 'ce_8', 'ce_1']);
    final out = ledger.items[0];
    final incoming = ledger.items[1];
    final original = ledger.items[2];
    expect(out.direction, 'out');
    expect(out.amountUnits, 200);
    expect(out.balanceAfterUnits, 9050);
    expect(out.description, 'صرف');
    expect(out.createdByName, 'مدير تجريبي');
    expect(incoming.direction, 'in');
    expect(incoming.amountUnits, 1250);
    expect(incoming.balanceAfterUnits, 9250);
    expect(incoming.description, 'قبض');
    expect(original.amountUnits, 1000);
    expect(original.balanceAfterUnits, 8000);

    final older = await api.treasury.cashLedger(before: ledger.nextCursor);
    expect(older.items.map((entry) => entry.id), ['ce_old']);
    expect(older.items.single.balanceAfterUnits, 7000);

    final summary = await api.treasury.summary();
    expect(summary.version, 9);
    expect(summary.activeCashUnits, 9050);
    expect(summary.netUnits, 52050);
    expect(summary.receivablesUnits, 45000);
    expect(summary.liabilitiesUnits, 12000);
    expect(summary.egyptianSourceUnits, 95000);
    expect(summary.egyptianConvertedUnits, 10000);
    expect(summary.activeCashTone, SummaryTone.positive);

    final home = await api.home.fetch();
    final card = home.summaries.singleWhere(
      (item) => item.key == 'treasury.activeCash',
    );
    expect(card.valueUnits, 9050);
    expect(card.tone, SummaryTone.positive);

    await api.session.logout();
    await api.session.login(username: 'employee.demo', password: 'x');
    await expectLater(
      api.treasury.addCashEntry(
        const CashEntryRequest(
          direction: CashDirection.cashIn,
          amountUnits: 1250,
          description: 'موظف',
        ),
        MutationMeta(expectedVersion: 9, requestId: 'employee-cash'),
      ),
      throwsA(
        isA<ForbiddenException>().having(
          (error) => error.statusCode,
          'status',
          403,
        ),
      ),
    );

    await api.session.logout();
    await api.session.login(username: 'admin.demo', password: 'x');
    final afterEmployee = await api.treasury.cashLedger();
    expect(afterEmployee.items.map((entry) => entry.id), [
      'ce_9',
      'ce_8',
      'ce_1',
    ]);
    expect((await api.treasury.summary()).activeCashUnits, 9050);
  });

  test(
    'DEF-015 rejects a non-positive amount and an unknown direction',
    () async {
      final api = FakeApiClient(latency: Duration.zero);
      await api.post(
        '/api/auth/login',
        body: {'username': 'admin.demo', 'password': 'x'},
      );

      await expectLater(
        api.post(
          '/api/treasury/cash-entries',
          body: {
            'requestId': 'zero',
            'expectedVersion': 7,
            'direction': 'in',
            'amountUnits': 0,
            'description': '',
          },
        ),
        throwsA(
          isA<BadRequestException>().having(
            (error) => error.code,
            'code',
            'VALIDATION_ERROR',
          ),
        ),
      );
      await expectLater(
        api.post(
          '/api/treasury/cash-entries',
          body: {
            'requestId': 'bad-direction',
            'expectedVersion': 7,
            'direction': 'transfer',
            'amountUnits': 10,
            'description': '',
          },
        ),
        throwsA(isA<BadRequestException>()),
      );
      await expectLater(
        api.post(
          '/api/treasury/cash-entries',
          body: {
            'requestId': 'missing-version',
            'direction': 'out',
            'amountUnits': 10,
          },
        ),
        throwsA(isA<BadRequestException>()),
      );

      final ledger = await api.get('/api/treasury/cash-ledger');
      final items = (ledger.data as Map)['items'] as List;
      expect(items.map((entry) => (entry as Map)['id']), ['ce_1']);
      final treasury = await api.get('/api/treasury');
      expect((treasury.data as Map)['version'], 7);
    },
  );
}

Future<ApiLayer> _admin() async {
  final api = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  await api.session.login(username: 'admin.demo', password: 'x');
  return api;
}
