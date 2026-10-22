import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ApiLayer> login(String username) async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    await api.session.login(username: username, password: 'x');
    return api;
  }

  SaveMasraweyaDayRequest request({
    int? previousValueUnits = 1,
    int? purchasesUnits = 9,
    int valueUnits = 4,
    int commissionUnits = 60,
  }) {
    return SaveMasraweyaDayRequest(
      businessDate: '2026-10-19',
      previousValueUnits: previousValueUnits,
      purchasesUnits: purchasesUnits,
      entries: [
        MasraweyaEntryDto(
          valueUnits: MoneyValue.known(valueUnits),
          commissionUnits: MoneyValue.known(commissionUnits),
        ),
      ],
    );
  }

  test('DEF-013 PUT stores the submitted day and GET returns it', () async {
    final api = await login('admin.demo');
    final before = await api.masraweya.getDay();
    expect(before.previousValueUnits?.units, 10000);
    expect(before.purchasesUnits?.units, 2000);
    expect(before.version, 2);
    expect(before.workTotalUnits?.units, 3050);
    expect(before.remainingUnits?.units, 8950);

    final saved = await api.masraweya.saveDay(
      request(),
      MutationMeta(expectedVersion: before.version, requestId: 'day-1'),
    );
    expect(saved.previousValueUnits?.units, 1);
    expect(saved.purchasesUnits?.units, 9);
    expect(saved.entries.single.valueUnits?.units, 4);
    expect(saved.entries.single.commissionUnits?.units, 60);
    expect(saved.version, 3);
    expect(saved.businessDate, '2026-10-19');
    // Server-owned totals are not recomputed from the submitted inputs.
    expect(saved.workTotalUnits, before.workTotalUnits);
    expect(saved.remainingUnits, before.remainingUnits);
    expect(saved.historicalAdjustmentUnits, before.historicalAdjustmentUnits);
    expect(saved.status, before.status);

    final again = await api.masraweya.getDay();
    expect(again.previousValueUnits?.units, 1);
    expect(again.purchasesUnits?.units, 9);
    expect(again.entries.single.valueUnits?.units, 4);
    expect(again.entries.single.commissionUnits?.units, 60);
    expect(again.version, 3);
    expect(again.workTotalUnits?.units, 3050);
    expect(again.remainingUnits?.units, 8950);
  });

  test('DEF-013 a stale expectedVersion is VERSION_CONFLICT', () async {
    final api = await login('admin.demo');
    await expectLater(
      api.masraweya.saveDay(
        request(previousValueUnits: 1),
        MutationMeta(expectedVersion: 1, requestId: 'stale'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    final day = await api.masraweya.getDay();
    expect(day.previousValueUnits?.units, 10000);
    expect(day.version, 2);

    await api.masraweya.saveDay(
      request(previousValueUnits: 1),
      MutationMeta(expectedVersion: 2, requestId: 'fresh'),
    );
    await expectLater(
      api.masraweya.saveDay(
        request(previousValueUnits: 8),
        MutationMeta(expectedVersion: 2, requestId: 'stale-after'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    final stored = await api.masraweya.getDay();
    expect(stored.previousValueUnits?.units, 1);
    expect(stored.version, 3);
  });

  test(
    'DEF-013 a repeated requestId returns the first day and is not applied again',
    () async {
      final api = await login('admin.demo');
      final fake = api.client as FakeApiClient;
      final first = await api.masraweya.saveDay(
        request(previousValueUnits: 1),
        MutationMeta(expectedVersion: 2, requestId: 'same'),
      );
      final replay = await api.masraweya.saveDay(
        request(previousValueUnits: 8, purchasesUnits: 3),
        MutationMeta(expectedVersion: 2, requestId: 'same'),
      );
      expect(replay.previousValueUnits, first.previousValueUnits);
      expect(replay.purchasesUnits, first.purchasesUnits);
      expect(replay.version, first.version);
      expect(fake.mutationRequestIds.where((id) => id == 'same'), ['same']);

      final day = await api.masraweya.getDay();
      expect(day.previousValueUnits?.units, 1);
      expect(day.purchasesUnits?.units, 9);
      expect(day.version, 3);
    },
  );

  test('DEF-013 a profile without masraweya write gets 403', () async {
    final api = await login('employee.demo');
    expect(api.permissions.canWrite(SectionKey.masraweya), isFalse);
    expect(api.permissions.canRead(SectionKey.masraweya), isFalse);
    await expectLater(
      api.masraweya.saveDay(
        request(),
        MutationMeta(expectedVersion: 2, requestId: 'emp'),
      ),
      throwsA(
        isA<ForbiddenException>().having(
          (error) => error.code,
          'code',
          'FORBIDDEN',
        ),
      ),
    );

    await api.session.logout();
    await api.session.login(username: 'admin.demo', password: 'x');
    final day = await api.masraweya.getDay();
    expect(day.previousValueUnits?.units, 10000);
    expect(day.purchasesUnits?.units, 2000);
    expect(day.version, 2);
  });
}
