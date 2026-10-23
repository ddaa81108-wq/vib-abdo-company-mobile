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
    );
    await api.session.login(username: username, password: 'x');
    return api;
  }

  test(
    'DEF-002 limited admin has collections.decide and the server accepts it',
    () async {
      final api = await login('limited.admin@example.invalid');
      expect(api.permissions.canDo(ManagementAction.collectionsDecide), isTrue);
      final ack = await api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: MutationMeta(expectedVersion: 1),
      );
      expect(ack.version, isNull);
      expect(ack.raw['status'], 'approved');
      expect(ack.raw.containsKey('version'), isFalse);
      final overview = await api.collections.overview();
      final submission = overview.submissions.firstWhere(
        (item) => item.id == 'sb_1',
      );
      expect(submission.status, 'approved');
      expect(submission.version, isNull);

      await api.session.logout();
      await api.session.login(
        username: 'employee@example.invalid',
        password: 'x',
      );
      expect(
        api.permissions.canDo(ManagementAction.collectionsDecide),
        isFalse,
      );
      await expectLater(
        api.collections.decide(
          'sb_1',
          CollectionDecision.approve,
          meta: MutationMeta(expectedVersion: 1),
        ),
        throwsA(isA<ForbiddenException>()),
      );
    },
  );

  test('DEF-003 full payment stores balance 0', () async {
    final api = await login('admin@example.invalid');
    final before = await api.accounts.list(AccountSection.customers);
    expect(before.totalItems, 10);
    expect(before.summary.netBalanceUnits?.units, 10635);
    final demo = before.page.items.firstWhere((card) => card.id == 'c_55');
    expect(demo.balanceUnits?.units, 320);
    final ack = await api.accounts.addTransaction(
      AccountSection.customers,
      'c_55',
      AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
      MutationMeta(expectedVersion: demo.version),
    );
    expect(ack.version, 5);

    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(card.balanceUnits?.units, 0);
    expect(card.version, 5);
    final after = await api.accounts.list(AccountSection.customers);
    expect(
      after.page.items
          .firstWhere((item) => item.id == 'c_55')
          .balanceUnits
          ?.units,
      0,
    );
    // The fixture summary is 10635. The stored change is 320 -> 0.
    expect(after.summary.netBalanceUnits?.units, 10315);
    expect(after.summary.totalDebtUnits?.units, 10315);

    await expectLater(
      api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
        MutationMeta(expectedVersion: 4, requestId: 'full-2'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    final still = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(still.balanceUnits?.units, 0);
    expect(still.version, 5);
  });

  test(
    'DEF-004 cancel copies the stored balance of the latest posted line',
    () async {
      final api = await login('admin@example.invalid');
      final ledger = await api.accounts.ledger(
        AccountSection.customers,
        'c_55',
      );
      final payment = ledger.page.items.firstWhere(
        (entry) => entry.id == 'tx_2',
      );
      expect(payment.balanceAfterUnits?.units, 320);
      await api.accounts.cancelTransaction(
        AccountSection.customers,
        'c_55',
        'tx_2',
        MutationMeta(expectedVersion: payment.version),
      );

      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      // tx_1 already stores balanceAfterUnits 500. The fake copies that value.
      expect(card.balanceUnits?.units, 500);
      final page = await api.accounts.list(AccountSection.customers);
      expect(
        page.page.items
            .firstWhere((item) => item.id == 'c_55')
            .balanceUnits
            ?.units,
        500,
      );
      // The fixture summary is 10635. The stored change is 320 -> 500.
      expect(page.summary.netBalanceUnits?.units, 10815);
      final again = await api.accounts.ledger(AccountSection.customers, 'c_55');
      expect(
        again.page.items.firstWhere((entry) => entry.id == 'tx_2').status,
        'reversed',
      );
    },
  );

  test(
    'DEF-005 a second decision after the status changed is a conflict',
    () async {
      final api = await login('admin@example.invalid');
      final ack = await api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: MutationMeta(expectedVersion: 1, requestId: 'decide-1'),
      );
      expect(ack.id, 'sb_1');
      expect(ack.version, isNull);
      expect(ack.raw['status'], 'approved');
      expect(ack.raw.containsKey('transactionId'), isTrue);
      expect(ack.raw.containsKey('version'), isFalse);

      await expectLater(
        api.collections.decide(
          'sb_1',
          CollectionDecision.reject,
          meta: MutationMeta(expectedVersion: 1, requestId: 'decide-2'),
        ),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.code, 'code', 'SUBMISSION_ALREADY_DECIDED')
              .having(
                (e) => e.message,
                'message',
                FakeApiClient.submissionAlreadyDecidedMessage,
              ),
        ),
      );
      final overview = await api.collections.overview();
      final submission = overview.submissions.firstWhere(
        (item) => item.id == 'sb_1',
      );
      expect(submission.status, 'approved');
      expect(submission.version, isNull);
      expect(submission.cashStatus, CashStatus.notApplicable);
    },
  );

  test(
    'partial payment stores the new balance and rejects a stale version',
    () async {
      final api = await login('admin@example.invalid');
      const stale = 'تم تعديل البيانات من مستخدم آخر';

      await expectLater(
        api.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          AccountTransactionRequest.partialPayment(
            inputValue: 100,
            date: DateTime(2026, 10, 19),
          ),
          MutationMeta(expectedVersion: 1, requestId: 'partial-stale'),
        ),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.code, 'code', 'VERSION_CONFLICT')
              .having((e) => e.message, 'message', stale),
        ),
      );
      final untouched = await api.accounts.get(
        AccountSection.customers,
        'c_55',
      );
      expect(untouched.balanceUnits?.units, 320);
      expect(untouched.version, 4);

      final ack = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.partialPayment(
          inputValue: 100,
          date: DateTime(2026, 10, 19),
        ),
        MutationMeta(expectedVersion: 4, requestId: 'partial-1'),
      );
      // The server stores 220: the card's 320 with the received 100 applied.
      expect(ack.version, 5);
      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits?.units, 220);
      expect(card.version, 5);
      final page = await api.accounts.list(AccountSection.customers);
      expect(
        page.page.items
            .firstWhere((item) => item.id == 'c_55')
            .balanceUnits
            ?.units,
        220,
      );
      // The fixture summary is 10635. The stored change is 320 -> 220.
      expect(page.summary.netBalanceUnits?.units, 10535);
      expect(page.summary.totalDebtUnits?.units, 10535);

      await expectLater(
        api.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          AccountTransactionRequest.partialPayment(
            inputValue: 100,
            date: DateTime(2026, 10, 19),
          ),
          MutationMeta(expectedVersion: 4, requestId: 'partial-2'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      final still = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(still.balanceUnits?.units, 220);
      expect(still.version, 5);
    },
  );

  test('DEF-016 home debt rows copy the stored card balance', () async {
    final api = await login('admin@example.invalid');
    final before = await api.home.fetch();
    expect(
      before.oldDebts!
          .singleWhere((row) => row.id == 'c_55')
          .balanceUnits
          ?.units,
      320,
    );
    expect(
      before.summaries
          .firstWhere((item) => item.section == 'customers')
          .valueUnits
          ?.units,
      10635,
    );

    await api.accounts.addTransaction(
      AccountSection.customers,
      'c_55',
      AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
      MutationMeta(expectedVersion: 4, requestId: 'def-016-full'),
    );
    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    final after = await api.home.fetch();
    final row = after.oldDebts!.singleWhere((item) => item.id == 'c_55');
    expect(card.balanceUnits?.units, 0);
    expect(row.balanceUnits, card.balanceUnits);
    expect(row.balanceUnits?.units, isNot(320));
    expect(row.section, 'customers');
    expect(row.debtAgeDays, 4);
    expect(
      after.summaries
          .firstWhere((item) => item.section == 'customers')
          .valueUnits
          ?.units,
      10315,
    );
    expect(
      after.summaries
          .firstWhere((item) => item.section == 'egyptian-deposits')
          .valueUnits
          ?.units,
      23750,
    );

    await api.session.logout();
    await api.session.login(username: 'guest@example.invalid', password: 'x');
    final guest = await api.home.fetch();
    expect(guest.oldDebts, isNull);
    expect(guest.summaries, isEmpty);
  });

  test(
    'DEF-016 partial payment and cancel publish the stored home balance',
    () async {
      final partial = await login('admin@example.invalid');
      await partial.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.partialPayment(
          inputValue: 100,
          date: DateTime(2026, 10, 19),
        ),
        MutationMeta(expectedVersion: 4, requestId: 'def-016-partial'),
      );
      final partialCard = await partial.accounts.get(
        AccountSection.customers,
        'c_55',
      );
      final partialHome = await partial.home.fetch();
      expect(partialCard.balanceUnits?.units, 220);
      expect(
        partialHome.oldDebts!
            .singleWhere((item) => item.id == 'c_55')
            .balanceUnits,
        partialCard.balanceUnits,
      );
      expect(
        partialHome.summaries
            .firstWhere((item) => item.section == 'customers')
            .valueUnits
            ?.units,
        10535,
      );

      final cancelled = await login('admin@example.invalid');
      final ledger = await cancelled.accounts.ledger(
        AccountSection.customers,
        'c_55',
      );
      final payment = ledger.page.items.firstWhere(
        (entry) => entry.id == 'tx_2',
      );
      await cancelled.accounts.cancelTransaction(
        AccountSection.customers,
        'c_55',
        'tx_2',
        MutationMeta(
          expectedVersion: payment.version,
          requestId: 'def-016-cancel',
        ),
      );
      final afterCard = await cancelled.accounts.get(
        AccountSection.customers,
        'c_55',
      );
      final afterHome = await cancelled.home.fetch();
      expect(afterCard.balanceUnits?.units, 500);
      expect(
        afterHome.oldDebts!
            .singleWhere((item) => item.id == 'c_55')
            .balanceUnits,
        afterCard.balanceUnits,
      );
    },
  );

  test('cash received follows approval and ignores a stale version', () async {
    final api = await login('admin@example.invalid');

    await expectLater(
      api.collections.markCashReceived(
        'sb_1',
        MutationMeta(expectedVersion: 99, requestId: 'cash-pending'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'SUBMISSION_NOT_APPROVED',
        ),
      ),
    );
    var overview = await api.collections.overview();
    var pending = overview.submissions.firstWhere((item) => item.id == 'sb_1');
    expect(pending.status, 'pending');
    expect(pending.version, isNull);
    expect(pending.cashStatus, CashStatus.notApplicable);

    var submission =
        overview.submissions.firstWhere((item) => item.id == 'sb_2');
    expect(submission.cashStatus, CashStatus.pending);
    expect(submission.version, isNull);
    expect(submission.status, 'approved');

    final ack = await api.collections.markCashReceived(
      'sb_2',
      MutationMeta(expectedVersion: 3, requestId: 'cash-1'),
    );
    expect(ack.version, isNull);
    expect(ack.raw['cashReceivedAt'], '2026-10-22T22:00:00.000Z');
    expect(ack.raw.containsKey('version'), isFalse);
    overview = await api.collections.overview();
    submission = overview.submissions.firstWhere((item) => item.id == 'sb_2');
    expect(submission.cashStatus, CashStatus.received);
    expect(submission.version, isNull);
    expect(submission.status, 'approved');

    final again = await api.collections.markCashReceived(
      'sb_2',
      MutationMeta(requestId: 'cash-again'),
    );
    expect(again.raw['replayed'], true);
    expect(again.raw['cashReceivedAt'], ack.raw['cashReceivedAt']);

    await expectLater(
      api.collections.markUnlinkedCashReceived(
        'ur_1',
        MutationMeta(expectedVersion: 1, requestId: 'ucash-1'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'SUBMISSION_NOT_APPROVED',
        ),
      ),
    );
    overview = await api.collections.overview();
    final stillPending = overview.unlinkedReceipts.firstWhere(
      (item) => item.id == 'ur_1',
    );
    expect(stillPending.status, 'pending');
    expect(stillPending.version, isNull);
    expect(stillPending.cashStatus, CashStatus.notApplicable);

    await api.collections.decideUnlinked(
      'ur_1',
      decision: CollectionDecision.approve,
      meta: MutationMeta(requestId: 'ucash-approve'),
    );
    final unlinkedAck = await api.collections.markUnlinkedCashReceived(
      'ur_1',
      MutationMeta(requestId: 'ucash-received'),
    );
    expect(unlinkedAck.version, isNull);
    expect(unlinkedAck.raw['cashReceivedAt'], '2026-10-22T22:00:00.000Z');
    overview = await api.collections.overview();
    final receipt = overview.unlinkedReceipts.firstWhere(
      (item) => item.id == 'ur_1',
    );
    expect(receipt.cashStatus, CashStatus.received);
    expect(receipt.version, isNull);
    expect(receipt.status, 'approved');
  });

  test('unlinked decision stores status and rejects a changed status',
      () async {
    final api = await login('admin@example.invalid');

    final ack = await api.collections.decideUnlinked(
      'ur_1',
      decision: CollectionDecision.approve,
      note: 'مطابقة اختبار',
      meta: MutationMeta(expectedVersion: 9, requestId: 'ulink-1'),
    );
    expect(ack.version, isNull);
    expect(ack.raw['status'], 'approved');
    expect(ack.balanceUnits, isNull);
    expect(ack.raw.containsKey('balanceUnits'), isFalse);
    expect(ack.raw.containsKey('version'), isFalse);
    var overview = await api.collections.overview();
    var receipt = overview.unlinkedReceipts.firstWhere(
      (item) => item.id == 'ur_1',
    );
    expect(receipt.status, 'approved');
    expect(receipt.version, isNull);

    await expectLater(
      api.collections.decideUnlinked(
        'ur_1',
        decision: CollectionDecision.reject,
        meta: MutationMeta(expectedVersion: 1, requestId: 'ulink-2'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'SUBMISSION_ALREADY_DECIDED',
        ),
      ),
    );
    overview = await api.collections.overview();
    receipt = overview.unlinkedReceipts.firstWhere((item) => item.id == 'ur_1');
    expect(receipt.status, 'approved');
    expect(receipt.version, isNull);
  });

  test(
    'close day compares the stored batch version through the repository',
    () async {
      final api = await login('admin@example.invalid');
      expect((await api.collections.overview()).batchId, 'b_1');

      await expectLater(
        api.collections.closeDay(
          batchId: 'b_1',
          meta: MutationMeta(expectedVersion: 99, requestId: 'close-99'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      expect((await api.collections.overview()).batchId, 'b_1');

      final ack = await api.collections.closeDay(
        batchId: 'b_1',
        meta: MutationMeta(expectedVersion: 1, requestId: 'close-1'),
      );
      expect(ack.id, 'ok');
      expect(ack.version, 2);
      expect((await api.collections.overview()).batchId, 'b_2');

      await expectLater(
        api.collections.closeDay(
          batchId: 'b_1',
          meta: MutationMeta(expectedVersion: 1, requestId: 'close-stale'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      expect((await api.collections.overview()).batchId, 'b_2');
    },
  );

  test(
    'purchase day finalize stores the day version and rejects a stale one',
    () async {
      final api = await login('admin@example.invalid');
      final before = await api.purchases.list(PurchaseBook.alBayan);
      final day = before.day!;
      expect(day.version, 3);
      expect(day.status, 'draft');

      await expectLater(
        api.purchases.finalizeDay(
          PurchaseBook.alBayan,
          MutationMeta(expectedVersion: 1, requestId: 'finalize-stale'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      final untouched = await api.purchases.list(PurchaseBook.alBayan);
      expect(untouched.day!.version, 3);
      expect(untouched.day!.status, 'draft');

      final ack = await api.purchases.finalizeDay(
        PurchaseBook.alBayan,
        MutationMeta(expectedVersion: 3, requestId: 'finalize-1'),
      );
      expect(ack.version, 4);
      final after = await api.purchases.list(PurchaseBook.alBayan);
      expect(after.day!.version, 4);
      expect(after.day!.status, 'finalized');

      await expectLater(
        api.purchases.finalizeDay(
          PurchaseBook.alBayan,
          MutationMeta(expectedVersion: 3, requestId: 'finalize-2'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      final still = await api.purchases.list(PurchaseBook.alBayan);
      expect(still.day!.version, 4);
      expect(still.day!.status, 'finalized');
    },
  );
}
