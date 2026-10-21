import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_logic.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('zero review is per card and only when the server allows it', (
    tester,
  ) async {
    final cards = [
      _card(
        'a',
        'عميل صفر',
        balanceUnits: 0,
        zeroReview: {'status': 'pending'},
      ),
      _card('a2', 'عميل ثان', balanceUnits: 0, zeroReview: {'pending': true}),
      _card(
        'b',
        'عميل مدين',
        balanceUnits: 320,
        zeroReview: {'status': 'pending'},
      ),
      _card(
        'c',
        'عميل راجع',
        balanceUnits: 0,
        zeroReview: {'status': 'confirmed'},
      ),
      _card(
        'sys',
        'كارت النظام',
        balanceUnits: 0,
        systemManaged: true,
        zeroReview: {'status': 'pending'},
      ),
      _card(
        'd',
        'مسموح',
        balanceUnits: 50,
        allowedActions: const [zeroReviewRecordAction],
      ),
      _card(
        'e',
        'ممنوع',
        balanceUnits: 0,
        zeroReview: {'status': 'pending'},
        allowedActions: const ['pin'],
      ),
      _card('f', 'مجهول', balanceUnits: 0, zeroReview: {'status': 'maybe'}),
      _card(
        'g',
        'عمر صفر',
        balanceUnits: 10,
        ageStatus: 'zero',
        zeroReview: {'status': 'pending'},
      ),
    ];
    await pumpFakeApp(
      tester,
      size: const Size(800, 2400),
      overrides: [
        accountsProvider.overrideWith((ref, section) async {
          return AccountsPage(
            page: Paged(items: cards),
            summary: const AccountsSummaryDto(activeCards: 9),
          );
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');

    expect(find.byKey(const Key('zero-review')), findsNothing);
    expect(find.byKey(const ValueKey('zero-review-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('zero-review-a2')), findsOneWidget);
    expect(find.byKey(const ValueKey('zero-review-d')), findsOneWidget);
    for (final id in ['b', 'c', 'sys', 'e', 'f', 'g']) {
      expect(find.byKey(ValueKey('zero-review-$id')), findsNothing);
    }
    expect(tester.takeException(), isNull);

    await go(tester, '/companies');
    expect(find.byKey(const ValueKey('zero-review-a')), findsNothing);
    expect(find.byKey(const ValueKey('zero-review-d')), findsNothing);

    await go(tester, '/customers');
    await tester.ensureVisible(find.byKey(const Key('assign-mode')));
    await tester.tap(find.byKey(const Key('assign-mode')));
    await settle(tester);
    expect(find.byType(Checkbox), findsNWidgets(8));
    final systemCard = find
        .ancestor(of: find.text('كارت النظام'), matching: find.byType(Material))
        .first;
    expect(
      find.descendant(of: systemCard, matching: find.byType(Checkbox)),
      findsNothing,
    );
  });

  testWidgets('Egyptian deposits send the pinned filter', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/egyptian-deposits');

    expect(find.byKey(const ValueKey('account-filter-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-filter-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-filter-debts')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-filter-settled')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-filter-pinned')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-filter-pendingReview')),
      findsNothing,
    );
    expect(find.text(AppStrings.pinnedTab), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('account-filter-pinned')),
    );
    await tester.tap(find.byKey(const ValueKey('account-filter-pinned')));
    await settle(tester);

    expect(
      fake.accountListQueries.any(
        (query) =>
            query.section == 'egyptian-deposits' && query.filter == 'pinned',
      ),
      isTrue,
    );
  });

  testWidgets('a filter change drops rows loaded for the previous query', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    fake.accountNextCursor = 'page-2';
    fake.accountNextItems = [
      {'id': 'c_extra', 'name': 'صفحة ثانية', 'balanceUnits': 10, 'version': 1},
    ];
    await go(tester, '/customers');

    expect(find.text('صفحة ثانية'), findsNothing);
    await tester.ensureVisible(find.text(AppStrings.loadMore));
    await tester.tap(find.text(AppStrings.loadMore));
    await settle(tester);
    expect(find.text('صفحة ثانية'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('account-filter-pinned')),
    );
    await tester.tap(find.byKey(const ValueKey('account-filter-pinned')));
    await settle(tester);

    expect(find.text('صفحة ثانية'), findsNothing);
    expect(find.text('عميل تجريبي'), findsOneWidget);
  });

  testWidgets('a late load-more page is not mixed into the new filter', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    fake.accountNextCursor = 'page-2';
    fake.accountNextItems = [
      {'id': 'c_late', 'name': 'صفحة متأخرة', 'balanceUnits': 10, 'version': 1},
    ];
    await go(tester, '/customers');
    final gate = Completer<void>();
    fake.pauseAccountLists = gate;

    await tester.ensureVisible(find.text(AppStrings.loadMore));
    await tester.tap(find.text(AppStrings.loadMore));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('account-filter-today')),
    );
    await tester.tap(find.byKey(const ValueKey('account-filter-today')));
    await tester.pump();
    gate.complete();
    fake.pauseAccountLists = null;
    await settle(tester);

    expect(find.text('صفحة متأخرة'), findsNothing);
    expect(find.text('عميل تجريبي'), findsOneWidget);
  });

  testWidgets(
    'phone show-all loads the remaining pages for the active filter',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers');
      expect(find.byKey(const Key('show-all-debts')), findsNothing);

      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      fake.accountNextCursor = 'page-2';
      fake.accountNextItems = [
        {
          'id': 'c_rest',
          'name': 'باقي الكروت',
          'balanceUnits': 8,
          'version': 1,
        },
      ];
      await go(tester, '/customers');
      expect(find.byType(ExpansionTile), findsOneWidget);
      await tester.tap(find.text(AppStrings.oldDebtsTitle));
      await settle(tester);
      expect(find.byKey(const Key('show-all-debts')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('account-search')), 'عميل');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('account-filter-pinned')),
      );
      await tester.tap(find.byKey(const ValueKey('account-filter-pinned')));
      await settle(tester);

      // Ten cards make the phone list taller than the viewport, so opening
      // the filter scrolls the bulletin away and its tile builds collapsed.
      await tester.ensureVisible(
        find.text(AppStrings.oldDebtsTitle, skipOffstage: false),
      );
      await settle(tester);
      if (find.byKey(const Key('show-all-debts')).evaluate().isEmpty) {
        await tester.tap(find.text(AppStrings.oldDebtsTitle));
        await settle(tester);
      }

      final before = fake.accountListQueries.length;
      await tester.ensureVisible(find.byKey(const Key('show-all-debts')));
      await tester.tap(find.byKey(const Key('show-all-debts')));
      await settle(tester);

      expect(find.text('باقي الكروت'), findsOneWidget);
      final paged = fake.accountListQueries
          .skip(before)
          .where((query) => query.cursor != null);
      expect(paged, hasLength(1));
      expect(paged.single.section, 'customers');
      expect(paged.single.filter, 'pinned');
      expect(paged.single.q, 'عميل');
      expect(paged.single.cursor, 'page-2');
    },
  );

  testWidgets(
    'an empty card name is not an integer error, and suggestions load',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/customers');
      await tester.tap(find.byKey(const Key('add-account')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('save-account')));
      await tester.pump();
      expect(find.text(AppStrings.nameRequired), findsOneWidget);
      expect(find.text(AppStrings.integerOnly), findsNothing);
      expect(fake.mutationRequestIds, isEmpty);
      expect(fake.suggestionQueries, isEmpty);

      fake.suggestionItems = [
        {'id': 'c_55', 'name': 'عميل تجريبي', 'phone': '0910000000'},
      ];
      await tester.enterText(find.byKey(const Key('create-name')), 'عميل');
      await settle(tester);
      expect(find.byKey(const Key('account-suggestions')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-c_55')), findsOneWidget);
      expect(fake.suggestionQueries.single.q, 'عميل');
      expect(fake.suggestionQueries.single.section, 'customers');

      await tester.enterText(_openingField, '1.5');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-account')));
      await tester.pump();
      expect(find.text(AppStrings.integerOnly), findsOneWidget);
      expect(fake.mutationRequestIds, isEmpty);

      await tester.enterText(_openingField, '');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-account')));
      await settle(tester);
      expect(fake.mutationRequestIds, hasLength(1));
      expect(find.byKey(const Key('save-account')), findsNothing);
    },
  );
}

final _openingField = find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText == AppStrings.openingBalance,
);

AccountCardDto _card(
  String id,
  String name, {
  int? balanceUnits,
  bool systemManaged = false,
  Map<String, dynamic>? zeroReview,
  List<String>? allowedActions,
  String? ageStatus,
}) {
  return AccountCardDto(
    id: id,
    name: name,
    balanceUnits: balanceUnits,
    currency: Currency.lyd,
    version: 4,
    systemManaged: systemManaged,
    zeroReview: zeroReview,
    allowedActions: allowedActions,
    ageStatus: ageStatus,
  );
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
