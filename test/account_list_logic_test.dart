import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_logic.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

void main() {
  test('load-more rows clear when that section filter or query changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const customers = AccountSection.customers;
    const companies = AccountSection.companies;
    final customersSub = container.listen(
      accountExtraCardsProvider(customers),
      (_, _) {},
    );
    final companiesSub = container.listen(
      accountExtraCardsProvider(companies),
      (_, _) {},
    );
    addTearDown(customersSub.close);
    addTearDown(companiesSub.close);

    container.read(accountExtraCardsProvider(customers).notifier).append([
      _card(id: 'extra'),
    ]);
    container.read(accountExtraCardsProvider(companies).notifier).append([
      _card(id: 'company-extra'),
    ]);

    container.read(accountFilterProvider(customers).notifier).state = 'pinned';

    expect(container.read(accountExtraCardsProvider(customers)), isEmpty);
    expect(
      container.read(accountExtraCardsProvider(companies)).single.id,
      'company-extra',
    );

    container.read(accountExtraCardsProvider(customers).notifier).append([
      _card(id: 'again'),
    ]);
    container.read(accountQueryProvider(customers).notifier).state = 'بحث';
    expect(container.read(accountExtraCardsProvider(customers)), isEmpty);
    expect(
      container.read(accountExtraCardsProvider(companies)).single.id,
      'company-extra',
    );
  });

  test(
    'an explicit clear drops load-more rows without changing the filter',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const section = AccountSection.customers;
      final sub = container.listen(
        accountExtraCardsProvider(section),
        (_, _) {},
      );
      addTearDown(sub.close);
      container.read(accountExtraCardsProvider(section).notifier).append([
        _card(id: 'extra'),
      ]);
      container.read(accountExtraCardsProvider(section).notifier).clear();
      expect(container.read(accountExtraCardsProvider(section)), isEmpty);
      expect(container.read(accountFilterProvider(section)), isNull);
    },
  );

  test(
    'Egyptian deposits use the same filters, without the customer review chip',
    () {
      final egyptian = accountListFilters(AccountSection.egyptianDeposits);
      expect(egyptian.map((tab) => tab.id), [
        null,
        'today',
        'debts',
        'settled',
        'pinned',
      ]);
      expect(egyptian.map((tab) => tab.label), contains(AppStrings.pinnedTab));
      expect(egyptian.first.label, AppStrings.activeTab);
      expect(
        accountListFilters(AccountSection.libyanDeposits).first.label,
        AppStrings.smartTab,
      );
      expect(
        accountListFilters(AccountSection.customers).map((tab) => tab.id),
        contains('pendingReview'),
      );
      expect(
        accountFilterCount(
          const AccountsSummaryDto(activeCards: 4, pendingReviewCount: 2),
          AccountFilterCount.activeCards,
        ),
        4,
      );
      expect(
        accountFilterCount(
          const AccountsSummaryDto(activeCards: 4, pendingReviewCount: 2),
          AccountFilterCount.pendingReview,
        ),
        2,
      );
      expect(accountFilterCount(const AccountsSummaryDto(), null), isNull);
    },
  );

  test('empty create name is not reported as an integer', () {
    expect(
      createAccountValidationMessage(name: '  ', opening: ''),
      AppStrings.nameRequired,
    );
    expect(
      createAccountValidationMessage(name: '', opening: '1.5'),
      AppStrings.nameRequired,
    );
    expect(
      createAccountValidationMessage(name: 'عميل', opening: '1.5'),
      AppStrings.integerOnly,
    );
    expect(createAccountValidationMessage(name: 'عميل', opening: ''), isNull);
    expect(
      createAccountValidationMessage(name: 'عميل', opening: '1,250'),
      isNull,
    );
    expect(openingBalanceOrNull(''), isNull);
    expect(openingBalanceOrNull('12'), 12);
  });

  test('a system card is not a routing target', () {
    final cards = [_card(id: 'a'), _card(id: 'sys', systemManaged: true)];
    expect(canSelectAccountForAssignment(cards[1]), isFalse);
    expect(assignmentTargetIds(['a', 'sys', 'gone'], cards), ['a']);
  });

  test('zero review follows allowedActions, then server balance and state', () {
    final admin = PermissionService()..applyFromServer(const [], role: 'admin');
    final writer = PermissionService()
      ..applyFromServer(
        ['debts.read', 'debts.write', 'debts.zero_review'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'manage'},
      );
    final reader = PermissionService()
      ..applyFromServer(
        ['debts.read', 'debts.zero_review'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'read'},
      );
    final employee = PermissionService()
      ..applyFromServer(
        ['debts.read', 'collections.read', 'collections.write'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'read'},
      );

    bool show(
      PermissionService permissions,
      AccountCardDto card, [
      AccountSection section = AccountSection.customers,
    ]) {
      return showCustomerZeroReview(
        permissions: permissions,
        section: section,
        card: card,
      );
    }

    expect(show(admin, _pending()), isTrue);
    expect(show(writer, _pending()), isTrue);
    expect(show(reader, _pending()), isFalse);
    expect(show(employee, _pending()), isFalse);
    expect(show(admin, _pending(balanceUnits: 320)), isFalse);
    expect(show(admin, _pending(balanceUnits: null)), isFalse);
    expect(show(admin, _pending(balanceUnits: -1)), isFalse);
    expect(show(admin, _pending(balanceUnits: 4, ageStatus: 'zero')), isFalse);
    expect(show(admin, _card(id: 'bare', balanceUnits: 0)), isFalse);
    expect(show(admin, _pending(zeroReview: {'status': 'confirmed'})), isFalse);
    expect(show(admin, _pending(zeroReview: {'status': 'maybe'})), isFalse);
    expect(show(admin, _pending(systemManaged: true)), isFalse);
    expect(show(admin, _pending(), AccountSection.companies), isFalse);
    expect(show(admin, _pending(), AccountSection.egyptianDeposits), isFalse);

    expect(
      show(
        employee,
        _card(
          id: 'server',
          balanceUnits: 50,
          allowedActions: const [zeroReviewRecordAction],
        ),
      ),
      isTrue,
    );
    expect(show(admin, _pending(allowedActions: const ['pin'])), isFalse);
    expect(
      show(admin, _pending(allowedActions: const ['debts.zero_review'])),
      isFalse,
    );
    expect(
      show(
        admin,
        _card(
          id: 'system-listed',
          balanceUnits: 0,
          systemManaged: true,
          allowedActions: const [zeroReviewRecordAction],
        ),
      ),
      isFalse,
    );
  });

  test(
    'show all walks remaining cursors and stops when the filter changes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const section = AccountSection.customers;
      final sub = container.listen(
        accountExtraCardsProvider(section),
        (_, _) {},
      );
      addTearDown(sub.close);
      final notifier = container.read(
        accountExtraCardsProvider(section).notifier,
      );

      var calls = 0;
      await notifier.loadRemaining(
        firstPageCursor: null,
        fetch: (cursor) async {
          calls++;
          return _page([_card(id: 'unused')]);
        },
        stillCurrent: () => true,
      );
      expect(calls, 0);

      await notifier.loadRemaining(
        firstPageCursor: 'c1',
        fetch: (cursor) async {
          if (cursor == 'c1') return _page([_card(id: 'p2')], 'c2');
          expect(cursor, 'c2');
          return _page([_card(id: 'p3')]);
        },
        stillCurrent: () => true,
      );
      expect(
        container
            .read(accountExtraCardsProvider(section))
            .map((card) => card.id),
        ['p2', 'p3'],
      );

      notifier.clear();
      notifier.append([_card(id: 'p2')], nextCursor: 'c2');
      await notifier.loadRemaining(
        firstPageCursor: 'c1',
        fetch: (cursor) async {
          expect(cursor, 'c2');
          return _page([_card(id: 'p3')]);
        },
        stillCurrent: () => true,
      );
      expect(
        container
            .read(accountExtraCardsProvider(section))
            .map((card) => card.id),
        ['p2', 'p3'],
      );

      notifier.clear();
      var allow = true;
      await notifier.loadRemaining(
        firstPageCursor: 'c1',
        fetch: (cursor) async {
          if (cursor == 'c1') return _page([_card(id: 'kept')], 'c2');
          allow = false;
          container.read(accountFilterProvider(section).notifier).state =
              'pinned';
          return _page([_card(id: 'stale')]);
        },
        stillCurrent: () =>
            allow && container.read(accountFilterProvider(section)) == null,
      );
      expect(
        container
            .read(accountExtraCardsProvider(section))
            .map((card) => card.id),
        isNot(contains('stale')),
      );
    },
  );

  test('a blank create name does not call suggestions', () async {
    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);
    await layer.session.login(username: 'admin.demo', password: 'x');
    final container = ProviderContainer(
      overrides: [apiLayerProvider.overrideWithValue(layer)],
    );
    addTearDown(container.dispose);
    final fake = layer.client as FakeApiClient;

    final blank = await container.read(
      accountNameSuggestionsProvider((AccountSection.customers, '   ')).future,
    );
    expect(blank, isEmpty);
    expect(fake.suggestionQueries, isEmpty);

    fake.suggestionItems = [
      {'id': 'c_9', 'name': 'قريب'},
    ];
    final found = await container.read(
      accountNameSuggestionsProvider((AccountSection.customers, 'قريب')).future,
    );
    expect(found.single.id, 'c_9');
    expect(fake.suggestionQueries.single.q, 'قريب');
    expect(fake.suggestionQueries.single.section, 'customers');
  });
}

AccountsPage _page(List<AccountCardDto> items, [String? nextCursor]) {
  return AccountsPage(
    page: Paged(items: items, nextCursor: nextCursor),
    summary: const AccountsSummaryDto(),
  );
}

AccountCardDto _card({
  required String id,
  int? balanceUnits = 0,
  bool systemManaged = false,
  Map<String, dynamic>? zeroReview,
  List<String>? allowedActions,
  String? ageStatus,
}) {
  return AccountCardDto(
    id: id,
    name: id,
    balanceUnits: balanceUnits,
    currency: Currency.lyd,
    version: 4,
    systemManaged: systemManaged,
    zeroReview: zeroReview,
    allowedActions: allowedActions,
    ageStatus: ageStatus,
  );
}

AccountCardDto _pending({
  String id = 'c_zero',
  int? balanceUnits = 0,
  bool systemManaged = false,
  Map<String, dynamic>? zeroReview = const {'status': 'pending'},
  List<String>? allowedActions,
  String? ageStatus,
}) {
  return _card(
    id: id,
    balanceUnits: balanceUnits,
    systemManaged: systemManaged,
    zeroReview: zeroReview,
    allowedActions: allowedActions,
    ageStatus: ageStatus,
  );
}
