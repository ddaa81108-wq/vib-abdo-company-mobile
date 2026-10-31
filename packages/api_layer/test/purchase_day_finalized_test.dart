import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const book = PurchaseBook.alBayan;
  final entry = PurchaseEntryRequest(
    itemCode: PurchaseItemCodes.vodafoneCash,
    egpValueUnits: 1000,
    calculationMode: CalculationMode.divide,
    exchangeRate: DecimalString.tryParse('9.5'),
    paidUnits: 100,
  );

  Future<ApiLayer> login(String username) async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: username, password: 'x');
    return api;
  }

  String fingerprint(PurchasesPage page) {
    final day = page.day!;
    final row = page.entries.firstWhere((entry) => entry.id == 'pe_1');
    Object? units(MoneyValue? value) => value?.asInt;
    return [
      day.numberLabel,
      day.status,
      day.correctionOpen,
      day.version,
      units(day.previousDebtUnits),
      units(day.todayResultUnits),
      units(day.todayPaidUnits),
      units(day.totalDebtUnits),
      units(day.vodafoneRemainingUnits),
      row.id,
      row.itemCode,
      row.itemLabel,
      units(row.egpValueUnits),
      units(row.resultUnits),
      units(row.paidUnits),
      units(row.remainingUnits),
      units(row.vodafoneConsumedUnits),
      units(row.dayClosingDebtUnits),
      row.version,
      row.dayVersion,
      units(page.registerTotals?.resultUnits),
      units(page.registerTotals?.paidUnits),
      units(page.registerTotals?.remainingUnits),
      units(day.previousDebtUnits),
      units(day.previousVodafoneUnits),
    ].join('|');
  }

  Future<void> expectDayFinalized(Future<MutationAck> Function() send) {
    return expectLater(
      send(),
      throwsA(
        isA<ConflictException>()
            .having(
              (error) => error.code,
              'code',
              FakeApiClient.dayFinalizedCode,
            )
            .having((error) => error.statusCode, 'status', 409)
            .having(
              (error) => error.message,
              'message',
              FakeApiClient.dayFinalizedMessage,
            )
            .having((error) => error.isVersionConflict, 'version', isFalse),
      ),
    );
  }

  test(
    'DEF-014 finalized purchase day rejects entry create update and delete',
    () async {
      final api = await login('admin.demo');
      final beforeFinalize = await api.purchases.list(book);
      expect(beforeFinalize.day!.status, 'draft');
      expect(beforeFinalize.day!.version, 3);

      final ack = await api.purchases.finalizeDay(
        book,
        MutationMeta(expectedVersion: 3, requestId: 'finalize-day'),
      );
      expect(ack.version, 4);
      final finalized = await api.purchases.list(book);
      final frozen = fingerprint(finalized);
      expect(finalized.day!.status, 'finalized');
      expect(finalized.day!.correctionOpen, isFalse);
      expect(finalized.day!.version, 4);
      expect(
        finalized.entries.firstWhere((entry) => entry.id == 'pe_1').id,
        'pe_1',
      );

      await expectDayFinalized(
        () => api.purchases.create(
          book,
          entry,
          MutationMeta(expectedVersion: 4, requestId: 'create-finalized'),
        ),
      );
      await expectDayFinalized(
        () => api.purchases.create(
          book,
          entry,
          MutationMeta(expectedVersion: 4, requestId: 'create-finalized'),
        ),
      );
      await expectDayFinalized(
        () => api.purchases.update(
          book,
          'pe_1',
          entry,
          MutationMeta(expectedVersion: 4, requestId: 'update-finalized'),
          entryVersion: 1,
        ),
      );
      await expectDayFinalized(
        () => api.purchases.update(
          book,
          'pe_1',
          entry,
          MutationMeta(expectedVersion: 4, requestId: 'update-finalized'),
          entryVersion: 1,
        ),
      );
      await expectDayFinalized(
        () => api.purchases.delete(
          book,
          'pe_1',
          MutationMeta(expectedVersion: 4, requestId: 'delete-finalized'),
          entryVersion: 1,
        ),
      );
      await expectDayFinalized(
        () => api.purchases.delete(
          book,
          'pe_1',
          MutationMeta(expectedVersion: 4, requestId: 'delete-finalized'),
          entryVersion: 1,
        ),
      );

      expect(fingerprint(await api.purchases.list(book)), frozen);

      final other = await api.purchases.list(PurchaseBook.simsim);
      expect(other.day!.status, 'draft');
      expect(other.merchant?.key, 'simsim');
      final otherAck = await api.purchases.create(
        PurchaseBook.simsim,
        entry,
        MutationMeta(expectedVersion: 3, requestId: 'simsim-create'),
      );
      expect(otherAck.id, 'pe_new');
      expect(fingerprint(await api.purchases.list(book)), frozen);
    },
  );

  test(
    'DEF-014 a stored requestId does not bypass the finalized-day check',
    () async {
      final api = await login('admin.demo');
      final fake = api.client as FakeApiClient;
      final createMeta = MutationMeta(
        expectedVersion: 3,
        requestId: 'create-once',
      );
      final updateMeta = MutationMeta(
        expectedVersion: 3,
        requestId: 'update-once',
      );
      final deleteMeta = MutationMeta(
        expectedVersion: 3,
        requestId: 'delete-once',
      );

      final created = await api.purchases.create(book, entry, createMeta);
      final updated = await api.purchases.update(
        book,
        'pe_1',
        entry,
        updateMeta,
        entryVersion: 1,
      );
      final deleted = await api.purchases.delete(
        book,
        'pe_1',
        deleteMeta,
        entryVersion: 1,
      );
      expect(created.id, 'pe_new');
      // Edit and delete answer with the row's own `entryId`.
      expect(updated.id, 'pe_1');
      expect(deleted.id, 'pe_1');
      final replayed = await api.purchases.create(book, entry, createMeta);
      expect(replayed.id, created.id);
      expect(replayed.version, created.version);
      expect(fake.mutationRequestIds.where((id) => id == 'create-once'), [
        'create-once',
      ]);

      final draft = fingerprint(await api.purchases.list(book));
      expect(draft, contains('draft'));

      await api.purchases.finalizeDay(
        book,
        MutationMeta(expectedVersion: 3, requestId: 'finalize-after-write'),
      );
      final frozen = fingerprint(await api.purchases.list(book));
      expect(frozen, contains('finalized'));
      expect(frozen, isNot(draft));

      await expectDayFinalized(
        () => api.purchases.create(book, entry, createMeta),
      );
      await expectDayFinalized(
        () => api.purchases.update(
          book,
          'pe_1',
          entry,
          updateMeta,
          entryVersion: 1,
        ),
      );
      await expectDayFinalized(
        () => api.purchases.delete(
          book,
          'pe_1',
          deleteMeta,
          entryVersion: 1,
        ),
      );
      expect(fingerprint(await api.purchases.list(book)), frozen);
      expect(fake.mutationRequestIds.where((id) => id == 'create-once'), [
        'create-once',
      ]);

      await api.purchases.setDayCorrection(
        book,
        '12',
        open: true,
        meta: MutationMeta(expectedVersion: 4, requestId: 'open-correction'),
      );
      final afterOpen = await api.purchases.create(book, entry, createMeta);
      expect(afterOpen.id, created.id);
      expect(afterOpen.version, created.version);
      final reopened = await api.purchases.list(book);
      expect(reopened.day!.status, 'finalized');
      expect(reopened.day!.correctionOpen, isTrue);
      expect(
        reopened.entries.firstWhere((entry) => entry.id == 'pe_1').id,
        'pe_1',
      );
      expect(reopened.day!.version, 4);
    },
  );

  test(
    'DEF-014 a rejected requestId can succeed once the day is editable',
    () async {
      final api = await login('admin.demo');
      await api.purchases.finalizeDay(
        book,
        MutationMeta(expectedVersion: 3, requestId: 'finalize-first'),
      );
      final meta = MutationMeta(
        expectedVersion: 4,
        requestId: 'retry-after-open',
      );
      await expectDayFinalized(() => api.purchases.create(book, entry, meta));

      await api.purchases.setDayCorrection(
        book,
        '12',
        open: true,
        meta: MutationMeta(expectedVersion: 4, requestId: 'open-for-retry'),
      );
      final ack = await api.purchases.create(book, entry, meta);
      expect(ack.id, 'pe_new');
      final page = await api.purchases.list(book);
      expect(page.day!.status, 'finalized');
      expect(page.day!.correctionOpen, isTrue);
      expect(page.entries.firstWhere((entry) => entry.id == 'pe_1').id, 'pe_1');
    },
  );

  test('DEF-014 opening and a draft day stay writable', () async {
    final api = await login('admin.demo');
    final created = await api.purchases.create(
      book,
      entry,
      MutationMeta(expectedVersion: 3, requestId: 'draft-create'),
    );
    expect(created.id, 'pe_new');
    final page = await api.purchases.list(book);
    expect(page.day!.status, 'draft');
    expect(page.day!.version, 3);

    await api.purchases.finalizeDay(
      book,
      MutationMeta(expectedVersion: 3, requestId: 'finalize-for-opening'),
    );
    final opening = await api.purchases.setOpening(
      book,
      previousDebtUnits: 10,
      previousVodafoneUnits: 20,
      meta: MutationMeta(expectedVersion: 4, requestId: 'opening-after'),
    );
    expect(opening.id, 'opening');
    final after = await api.purchases.list(book);
    expect(after.day!.status, 'finalized');
    expect(after.day!.version, 4);
    expect(after.day!.previousDebtUnits?.asInt, 10);
    expect(after.day!.previousVodafoneUnits?.asInt, 20);
    expect(after.entries.firstWhere((entry) => entry.id == 'pe_1').id, 'pe_1');
  });

  test('DEF-014 a profile without purchases.write still gets 403', () async {
    final api = await login('employee.demo');
    (api.client as FakeApiClient).purchaseFixtureStatus = 'finalized';
    await expectLater(
      api.purchases.create(
        book,
        entry,
        MutationMeta(expectedVersion: 3, requestId: 'employee-create'),
      ),
      throwsA(
        isA<ForbiddenException>()
            .having((error) => error.code, 'code', 'FORBIDDEN')
            .having((error) => error.statusCode, 'status', 403),
      ),
    );
    await expectLater(
      api.purchases.delete(
        book,
        'pe_1',
        MutationMeta(expectedVersion: 3, requestId: 'employee-delete'),
        entryVersion: 1,
      ),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
