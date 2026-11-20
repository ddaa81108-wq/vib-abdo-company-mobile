import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/search/account_search_controller.dart';
import 'package:vib_abdo_company_mobile/features/search/search_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets(
    'one app-bar tap focuses typing; tapping again restores keyboard',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 844));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/companies');
      await tester.tap(find.byKey(const Key('unified-search-open')));
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(
        find.byKey(const Key('unified-search')),
      );
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      input.focusNode!.unfocus();
      await tester.pump();
      await tester.tap(find.byKey(const Key('unified-search-open')));
      await tester.pumpAndSettle();
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byKey(const Key('search-scope')));
      await tester.pumpAndSettle();
      expect(find.text('القسم الحالي: قسم ديون الشركات'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all four lists have only the shared app-bar search; collection search stays',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(390, 844));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      for (final section in AccountSection.values) {
        await go(tester, '/${section.path}');
        expect(find.byKey(const Key('account-search')), findsNothing);
        expect(find.byKey(const Key('unified-search-open')), findsOneWidget);
        expect(find.byKey(Key('screen-${section.path}')), findsOneWidget);
        if (section == AccountSection.egyptianDeposits) {
          expect(find.byKey(const Key('exchange-rate-card')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
      await go(tester, '/collections');
      expect(find.byKey(const Key('collections-search')), findsOneWidget);
    },
  );

  testWidgets(
    'section search reads the server pages and opens an off-page card',
    (tester) async {
      final layer = await pumpFakeApp(
        tester,
        size: const Size(440, 1400),
        overrides: [
          accountCardProvider.overrideWith(
            (ref, key) async => AccountCardDto(
              id: key.$2,
              name: 'نتيجة الصفحة الثانية',
              balanceUnits: MoneyValue.known(987654321),
              currency: key.$1.currency,
            ),
          ),
        ],
      );
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      fake.accountNextCursor = 'next-search-page';
      fake.accountNextItems = [
        {
          'id': 'outside-first-page',
          'name': 'نتيجة الصفحة الثانية',
          'balanceUnits': 987654321,
          'currency': 'LYD',
          'activeAssigneeName': 'موظف الصفحة الثانية',
        },
      ];
      await go(tester, '/search?section=companies');
      await tester.tap(find.byKey(const Key('search-scope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('القسم الحالي: قسم ديون الشركات').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('unified-search')), 'نتيجة');
      await tester.pump(SearchScreen.debounce);
      await tester.pumpAndSettle();
      final more = find.byKey(const Key('search-load-more'));
      await tester.scrollUntilVisible(
        more,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(SearchScreen.screenKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      final queries = fake.accountListQueries
          .where((q) => q.q == 'نتيجة')
          .toList();
      expect(queries.map((q) => q.section).toSet(), {'companies'});
      expect(queries.last.cursor, 'next-search-page');
      expect(fake.accountSearchQueries, isEmpty);
      expect(find.text('موجّه إلى: موظف الصفحة الثانية'), findsOneWidget);
      final show = find.byKey(
        const Key('search-card-companies-outside-first-page'),
      );
      await tester.scrollUntilVisible(
        show.hitTestable(),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(SearchScreen.screenKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(show.hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('account-card-outside-first-page')),
        findsOneWidget,
      );
      expect(find.text('نتيجة الصفحة الثانية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search scope exposes only the signed-in permissions', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 844));
    await signIn(tester, username: 'other.employee', password: 'demo-only');
    await go(tester, '/search');
    await tester.tap(find.byKey(const Key('search-scope')));
    await tester.pumpAndSettle();
    expect(find.text('قسم ديون العملاء'), findsWidgets);
    expect(find.text('قسم ديون الشركات'), findsNothing);
    expect(find.text('أمانات مصرية'), findsNothing);
  });

  testWidgets(
    'typing, scope changes and account switches discard obsolete responses',
    (tester) async {
      final repository = _Repository();
      var user = 'first-user';
      final controller = AccountSearchController(
        repository: () => repository,
        canRead: (_) => true,
        currentUserId: () => user,
      );
      addTearDown(controller.dispose);
      final old = Completer<AccountsPage>();
      repository.onList = (_, q, cursor) => old.future;
      controller.search('قديم');
      await tester.pump(AccountSearchController.debounce);
      repository.onList = (_, q, cursor) async =>
          _page('new', cursor: 'second');
      controller.setScope(AccountSection.egyptianDeposits);
      await tester.pump(AccountSearchController.debounce);
      old.complete(_page('old'));
      await tester.pump();
      expect(controller.items.single.id, 'new');
      expect(controller.items.single.currency, Currency.egp);
      final late = Completer<AccountsPage>();
      repository.onList = (_, q, cursor) => late.future;
      final loading = controller.loadMore();
      user = 'second-user';
      late.complete(_page('other-session'));
      await loading;
      expect(controller.items.single.id, 'new');
    },
  );

  testWidgets(
    'failed next page preserves results and cursor; retry merges without duplicates',
    (tester) async {
      final repository = _Repository();
      final controller = AccountSearchController(
        repository: () => repository,
        canRead: (_) => true,
        currentUserId: () => 'user',
      );
      addTearDown(controller.dispose);
      repository.onList = (_, q, cursor) async =>
          _page('first', cursor: 'second');
      controller.setScope(AccountSection.customers);
      controller.search('عميل');
      await tester.pump(AccountSearchController.debounce);
      await tester.pump();
      repository.onList = (_, q, cursor) async => throw StateError('offline');
      await controller.loadMore();
      expect(controller.items.single.id, 'first');
      expect(controller.nextCursors[AccountSection.customers], 'second');
      expect(controller.error, isNotEmpty);
      repository.onList = (_, q, cursor) async => AccountsPage(
        page: Paged(items: [_card('first'), _card('second')]),
        summary: const AccountsSummaryDto(),
      );
      controller.retry();
      await tester.pump();
      expect(controller.items.map((hit) => hit.id), ['first', 'second']);
      expect(controller.nextCursors[AccountSection.customers], isNull);
      expect(controller.error, isEmpty);
      controller.search('ع');
      await tester.pump(AccountSearchController.debounce);
      expect(controller.items, isEmpty);
      expect(controller.busy, isFalse);
    },
  );
}

AccountCardDto _card(String id) => AccountCardDto(
  id: id,
  name: id,
  balanceUnits: MoneyValue.known(987654321),
  currency: Currency.egp,
);
AccountsPage _page(String id, {String? cursor}) => AccountsPage(
  page: Paged(items: [_card(id)], nextCursor: cursor),
  summary: const AccountsSummaryDto(),
);

class _Repository implements AccountsRepository {
  Future<AccountsPage> Function(AccountSection, String?, String?)? onList;

  @override
  Future<List<GlobalAccountHit>> search(String q) =>
      throw StateError('Capped search endpoint must not be used');
  @override
  Future<AccountsPage> list(
    AccountSection section, {
    String? cursor,
    int limit = 100,
    String? q,
    String? filter,
  }) {
    if (limit != 30) throw StateError('Unexpected search page size');
    return onList!(section, q, cursor);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
