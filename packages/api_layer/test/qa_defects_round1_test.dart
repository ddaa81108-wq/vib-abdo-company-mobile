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
      expect(before.page.items.single.balanceUnits, 320);
      final ack = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
        MutationMeta(expectedVersion: before.page.items.single.version),
      );
      expect(ack.version, 5);

      final card = await api.accounts.get(AccountSection.customers, 'c_55');
      expect(card.balanceUnits, 0);
      expect(card.version, 5);
      final after = await api.accounts.list(AccountSection.customers);
      expect(after.page.items.single.balanceUnits, 0);
      expect(after.summary.netBalanceUnits, 0);
      expect(after.summary.totalDebtUnits, 0);

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
      expect(page.page.items.single.balanceUnits, 500);
      expect(page.summary.netBalanceUnits, 500);
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
}
