import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fake login -> me -> accounts -> mutation with requestId -> logout',
    () async {
      final api = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
        ),
      );
      await api.session.login(
        username: 'employee@example.invalid',
        password: 'x',
      );
      expect(api.session.state, isA<SessionAuthenticated>());
      expect(api.permissions.canRead(SectionKey.collections), isTrue);
      expect(api.permissions.canRead(SectionKey.treasury), isFalse);

      final page = await api.accounts.list(AccountSection.customers);
      expect(page.summary.totalDebtUnits?.units, 10635);
      expect(page.summary.netBalanceUnits?.units, 10635);
      expect(page.totalItems, 10);
      final demo = page.page.items.firstWhere((card) => card.id == 'c_55');
      expect(
        api.money.format(demo.balanceUnits!.units!, demo.currency),
        '320 د.ل',
      );

      final meta = MutationMeta(expectedVersion: demo.version);
      await expectLater(
        api.accounts.addTransaction(
          AccountSection.customers,
          'c_55',
          AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
          meta,
        ),
        throwsA(isA<ForbiddenException>()),
      );

      await expectLater(
        api.collections.closeDay(batchId: 'b_1', meta: MutationMeta()),
        throwsA(isA<ForbiddenException>()),
      );
      expect(await api.notifications.fetchUnreadCount(), 1);

      await api.session.logout();
      expect(api.session.state, isA<SessionUnauthenticated>());
    },
  );

  test('fake admin: explicit permissions, home, cashStatus from server, versioned decisions', () async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    await api.session.login(username: 'admin@example.invalid', password: 'x');
    expect(api.permissions.fullAccess, isTrue);
    expect(api.permissions.canWrite(SectionKey.treasury), isTrue);
    expect(api.permissions.canDo(ManagementAction.collectionsDecide), isTrue);

    final home = await api.home.fetch();
    expect(home.businessDate, '2026-10-19');
    expect(home.summaries.length, 5);
    final egp = home.summaries.firstWhere(
      (s) => s.section == 'egyptian-deposits',
    );
    expect(egp.currency, Currency.egp);
    expect(egp.tone, SummaryTone.positive);
    expect(api.money.formatOrDash(egp.valueUnits, egp.currency!), '23,750 ج.م');
    final customers = home.summaries.firstWhere(
      (s) => s.section == 'customers',
    );
    expect(customers.valueUnits?.units, 10635);
    expect(home.counters['customers'], 10);
    expect(
      home.summaries.firstWhere((s) => s.section == 'reports').valueUnits,
      isNull,
    );
    expect(home.oldDebts, isNotNull);

    final overview = await api.collections.overview();
    final approved = overview.submissions.firstWhere((s) => s.id == 'sb_2');
    expect(approved.cashStatus, CashStatus.pending);
    expect(overview.submissions.first.cashStatus, CashStatus.notApplicable);
    final pendingUnlinked =
        overview.unlinkedReceipts.firstWhere((r) => r.id == 'ur_1');
    expect(pendingUnlinked.version, 1);
    expect(pendingUnlinked.cashStatus, CashStatus.notApplicable);
    final rejectedUnlinked =
        overview.unlinkedReceipts.firstWhere((r) => r.id == 'ur_2');
    expect(rejectedUnlinked.status, 'rejected');
    expect(rejectedUnlinked.version, 4);
    expect(rejectedUnlinked.cashStatus, CashStatus.pending);

    // Without expectedVersion the repository refuses to send, per API contract.
    expect(
      () => api.collections.markCashReceived('sb_2', MutationMeta()),
      throwsArgumentError,
    );
    final ack = await api.collections.markCashReceived(
      'sb_2',
      MutationMeta(expectedVersion: approved.version),
    );
    expect(ack.version, 4);
    final afterCash = await api.collections.overview();
    expect(
      afterCash.submissions.firstWhere((s) => s.id == 'sb_2').cashStatus,
      CashStatus.received,
    );
    await api.session.logout();
  });

  test('employee home is server-filtered', () async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
    );
    await api.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );
    expect(api.permissions.fullAccess, isFalse);
    expect(api.permissions.canDo(ManagementAction.collectionsDecide), isFalse);
    final home = await api.home.fetch();
    expect(home.summaries.map((s) => s.section), ['customers', 'collections']);
  });
}
