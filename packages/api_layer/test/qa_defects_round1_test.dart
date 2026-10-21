import 'package:flutter_api_layer/api_layer.dart';
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
      expect(ack.version, 2);
      final overview = await api.collections.overview();
      final submission = overview.submissions.firstWhere(
        (item) => item.id == 'sb_1',
      );
      expect(submission.status, 'approved');

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

  test(
    'DEF-003 full payment stores balance 0',
    () async {
      final api = await login('admin@example.invalid');
      final before = await api.accounts.list(AccountSection.customers);
      expect(before.totalItems, 10);
      expect(before.summary.netBalanceUnits, 10635);
      final demo = before.page.items.firstWhere((card) => card.id == 'c_55');
      expect(demo.balanceUnits, 320);
      final ack = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
        MutationMeta(expectedVersion: demo.version),
      );
      expect(ack.version, 5);

      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits, 0);
      expect(card.version, 5);
      final after = await api.accounts.list(AccountSection.customers);
      expect(
        after.page.items.firstWhere((item) => item.id == 'c_55').balanceUnits,
        0,
      );
      expect(
        after.page.items.firstWhere((item) => item.id == 'c_56').balanceUnits,
        150,
      );
      // The fixture summary is 10635. The stored change is 320 -> 0.
      expect(after.summary.netBalanceUnits, 10315);
      expect(after.summary.totalDebtUnits, 10315);
      expect(after.totalItems, 10);

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
      expect(still.balanceUnits, 0);
      expect(still.version, 5);
    },
  );

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
      expect(payment.balanceAfterUnits, 320);
      await api.accounts.cancelTransaction(
        AccountSection.customers,
        'c_55',
        'tx_2',
        MutationMeta(expectedVersion: payment.version),
      );

      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      // tx_1 already stores balanceAfterUnits 500. The fake copies that value.
      expect(card.balanceUnits, 500);
      final page = await api.accounts.list(AccountSection.customers);
      expect(
        page.page.items.firstWhere((item) => item.id == 'c_55').balanceUnits,
        500,
      );
      // The fixture summary is 10635. The stored change is 320 -> 500.
      expect(page.summary.netBalanceUnits, 10815);
      expect(page.totalItems, 10);
      final again = await api.accounts.ledger(AccountSection.customers, 'c_55');
      expect(
        again.page.items.firstWhere((entry) => entry.id == 'tx_2').status,
        'reversed',
      );
    },
  );

  test(
    'DEF-005 a second decision with the same version is a conflict',
    () async {
      final api = await login('admin@example.invalid');
      final ack = await api.collections.decide(
        'sb_1',
        CollectionDecision.approve,
        meta: MutationMeta(expectedVersion: 1, requestId: 'decide-1'),
      );
      expect(ack.version, 2);

      const message = 'تم تعديل البيانات من مستخدم آخر';
      await expectLater(
        api.collections.decide(
          'sb_1',
          CollectionDecision.reject,
          meta: MutationMeta(expectedVersion: 1, requestId: 'decide-2'),
        ),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.code, 'code', 'VERSION_CONFLICT')
              .having((e) => e.message, 'message', message),
        ),
      );
      final overview = await api.collections.overview();
      final submission = overview.submissions.firstWhere(
        (item) => item.id == 'sb_1',
      );
      expect(submission.status, 'approved');
      expect(submission.version, 2);
      expect(submission.cashStatus, CashStatus.notApplicable);
    },
  );

  test('partial payment stores the new balance and rejects a stale version',
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
    final untouched = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(untouched.balanceUnits, 320);
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
    expect(card.balanceUnits, 220);
    expect(card.version, 5);
    final page = await api.accounts.list(AccountSection.customers);
    expect(
      page.page.items.firstWhere((item) => item.id == 'c_55').balanceUnits,
      220,
    );
    // The fixture summary is 10635. The stored change is 320 -> 220.
    expect(page.summary.netBalanceUnits, 10535);
    expect(page.summary.totalDebtUnits, 10535);
    expect(page.totalItems, 10);

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
    expect(still.balanceUnits, 220);
    expect(still.version, 5);
  });

  test('cash received stores the new version and rejects a stale one',
      () async {
    final api = await login('admin@example.invalid');

    await expectLater(
      api.collections.markCashReceived(
        'sb_2',
        MutationMeta(expectedVersion: 99, requestId: 'cash-stale'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    var overview = await api.collections.overview();
    var submission =
        overview.submissions.firstWhere((item) => item.id == 'sb_2');
    expect(submission.cashStatus, CashStatus.pending);
    expect(submission.version, 3);
    expect(submission.status, 'approved');

    final ack = await api.collections.markCashReceived(
      'sb_2',
      MutationMeta(expectedVersion: 3, requestId: 'cash-1'),
    );
    expect(ack.version, 4);
    overview = await api.collections.overview();
    submission = overview.submissions.firstWhere((item) => item.id == 'sb_2');
    expect(submission.cashStatus, CashStatus.received);
    expect(submission.version, 4);
    expect(submission.status, 'approved');

    final unlinkedAck = await api.collections.markUnlinkedCashReceived(
      'ur_1',
      MutationMeta(expectedVersion: 1, requestId: 'ucash-1'),
    );
    expect(unlinkedAck.version, 2);
    overview = await api.collections.overview();
    final receipt = overview.unlinkedReceipts.single;
    expect(receipt.cashStatus, CashStatus.received);
    expect(receipt.version, 2);
    expect(receipt.status, 'pending');

    await expectLater(
      api.collections.markUnlinkedCashReceived(
        'ur_1',
        MutationMeta(expectedVersion: 1, requestId: 'ucash-stale'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    overview = await api.collections.overview();
    expect(overview.unlinkedReceipts.single.version, 2);
    expect(overview.unlinkedReceipts.single.cashStatus, CashStatus.received);
  });

  test('unlinked decision stores status and version and rejects a stale one',
      () async {
    final api = await login('admin@example.invalid');

    await expectLater(
      api.collections.decideUnlinked(
        'ur_1',
        decision: CollectionDecision.reject,
        meta: MutationMeta(expectedVersion: 9, requestId: 'ulink-stale'),
      ),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'VERSION_CONFLICT',
        ),
      ),
    );
    var overview = await api.collections.overview();
    expect(overview.unlinkedReceipts.single.status, 'pending');
    expect(overview.unlinkedReceipts.single.version, 1);

    final ack = await api.collections.decideUnlinked(
      'ur_1',
      decision: CollectionDecision.approve,
      meta: MutationMeta(expectedVersion: 1, requestId: 'ulink-1'),
    );
    expect(ack.version, 2);
    overview = await api.collections.overview();
    expect(overview.unlinkedReceipts.single.status, 'approved');
    expect(overview.unlinkedReceipts.single.version, 2);

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
          'VERSION_CONFLICT',
        ),
      ),
    );
    overview = await api.collections.overview();
    expect(overview.unlinkedReceipts.single.status, 'approved');
    expect(overview.unlinkedReceipts.single.version, 2);
  });

  test('purchase day finalize stores the day version and rejects a stale one',
      () async {
    final api = await login('admin@example.invalid');
    final before = await api.purchases.list(PurchaseBook.alBayan);
    final day = before.page.items.single;
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
    expect(untouched.page.items.single.version, 3);
    expect(untouched.page.items.single.status, 'draft');

    final ack = await api.purchases.finalizeDay(
      PurchaseBook.alBayan,
      MutationMeta(expectedVersion: 3, requestId: 'finalize-1'),
    );
    expect(ack.version, 4);
    final after = await api.purchases.list(PurchaseBook.alBayan);
    expect(after.page.items.single.version, 4);
    expect(after.page.items.single.status, 'finalized');

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
    expect(still.page.items.single.version, 4);
    expect(still.page.items.single.status, 'finalized');
  });

  test(
    'a full payment updates the ten-card summary and a replay does not apply it twice',
    () async {
      final api = await login('admin@example.invalid');
      final request = AccountTransactionRequest.fullPayment(
        date: DateTime(2026, 10, 19),
      );
      const requestId = 'full-once';
      final first = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        MutationMeta(expectedVersion: 4, requestId: requestId),
      );
      expect(first.id, 'tx_new');
      expect(first.version, 5);

      final after = await api.accounts.list(AccountSection.customers);
      expect(after.totalItems, 10);
      expect(
        after.page.items.firstWhere((item) => item.id == 'c_55').balanceUnits,
        0,
      );
      expect(after.summary.netBalanceUnits, 10315);
      expect(after.summary.totalDebtUnits, 10315);

      final replay = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        request,
        MutationMeta(expectedVersion: 4, requestId: requestId),
      );
      expect(replay.id, first.id);
      expect(replay.version, first.version);

      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits, 0);
      expect(card.version, 5);
      final still = await api.accounts.list(AccountSection.customers);
      expect(still.summary.netBalanceUnits, 10315);
      expect(
        still.page.items.firstWhere((item) => item.id == 'c_56').balanceUnits,
        150,
      );
    },
  );

  test('DEF-006 an employee reading the treasury gets 403', () async {
    final api = await login('employee@example.invalid');
    await expectLater(
      api.treasury.summary(),
      throwsA(
        isA<ForbiddenException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.code, 'code', 'FORBIDDEN'),
      ),
    );
    final card = await api.accounts.get(AccountSection.customers, 'c_55');
    expect(card.balanceUnits, 320);
    expect(card.version, 4);
  });
}
