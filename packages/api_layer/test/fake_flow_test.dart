import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/models/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake login -> me -> accounts -> mutation with requestId -> logout',
      () async {
    final api = ApiLayer.create(
        config:
            const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true));
    await api.session
        .login(username: 'employee@example.invalid', password: 'x');
    expect(api.session.state, isA<SessionAuthenticated>());
    expect(api.permissions.canRead(SectionKey.collections), isTrue);
    expect(api.permissions.canRead(SectionKey.treasury), isFalse);

    final page = await api.accounts.list(AccountSection.customers);
    expect(page.totalDebtUnits, 320);
    expect(
        api.money.format(page.page.items.first.balanceUnits!,
            page.page.items.first.currency),
        '320 د.ل');

    final meta = MutationMeta(expectedVersion: page.page.items.first.version);
    final ack = await api.accounts.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.fullPayment(date: DateTime(2026, 10, 19)),
        meta);
    expect(ack.version, 5);

    await expectLater(
        api.collections.closeDay(batchId: 'b_1', meta: MutationMeta()),
        throwsA(isA<ForbiddenException>()));
    expect(await api.notifications.fetchUnreadCount(), 1);

    await api.session.logout();
    expect(api.session.state, isA<SessionUnauthenticated>());
  });
}
