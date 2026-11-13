import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/search/search_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('unified search follows the website account-search rules', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/search');

    await tester.enterText(find.byKey(const Key('unified-search')), 'ع');
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    expect(fake.accountSearchQueries, isEmpty);
    expect(find.byKey(const Key('search-results')), findsNothing);

    fake.accountSearchItems = [
      {
        'id': 'c_55',
        'name': 'عميل تجريبي',
        'section': 'customers',
        'balanceUnits': 320,
        'currency': 'LYD',
        'activeAssignmentId': 'as_1',
        'activeAssigneeName': 'موظف استلام تجريبي',
      },
      {
        'id': 'c_eg_01',
        'name': 'أمانة مصرية',
        'section': 'egyptian-deposits',
        'balanceUnits': -40,
        'currency': 'EGP',
      },
    ];
    await tester.enterText(find.byKey(const Key('unified-search')), 'عميل');
    await tester.pump();
    expect(find.text(AppStrings.searchBusy), findsOneWidget);
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    expect(fake.accountSearchQueries, ['عميل']);
    expect(fake.suggestionQueries, isEmpty);
    expect(find.text('قسم ديون العملاء'), findsOneWidget);
    expect(find.text('موجّه إلى: موظف استلام تجريبي'), findsOneWidget);
    expect(find.text('عرض الكارت'), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
    expect(find.text('أمانات مصرية'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('ج.م'), findsWidgets);

    await tester.tap(find.byKey(const Key('search-card-customers-c_55')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-card-c_55')), findsOneWidget);

    await go(tester, '/search');
    fake.accountSearchItems = const [];
    await tester.enterText(find.byKey(const Key('unified-search')), 'zzzz');
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.searchNoAccounts), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pump();
    expect(find.byKey(const Key('search-results')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
