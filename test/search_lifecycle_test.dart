import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/search/search_screen.dart';

import 'support/pump_app.dart';
import 'support/account_search_fixture.dart';

void main() {
  testWidgets('a slower search does not replace a newer query', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 900));
    final fake = layer.client as FakeApiClient;
    scriptAccountSearch(fake, [
      {
        'id': 'old',
        'name': 'نتيجة أولى',
        'section': 'customers',
        'balanceUnits': 10,
        'currency': 'LYD',
      },
    ]);
    final gate = Completer<void>();
    final oldPage = fake.accountQueryPage!;
    fake.accountQueryPage = (section, query, cursor) async {
      final page = await oldPage(section, query, cursor);
      await gate.future;
      return page;
    };
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/search');

    await tester.enterText(find.byKey(const Key('unified-search')), 'قديم');
    await tester.pump(SearchScreen.debounce);
    await tester.pump();

    scriptAccountSearch(fake, [
      {
        'id': 'new',
        'name': 'نتيجة ثانية',
        'section': 'customers',
        'balanceUnits': 20,
        'currency': 'LYD',
      },
    ]);
    await tester.enterText(find.byKey(const Key('unified-search')), 'جديد');
    await tester.pump(SearchScreen.debounce);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('نتيجة ثانية'), findsWidgets);
    expect(find.text('نتيجة أولى'), findsNothing);
    expect(find.text('جديد'), findsOneWidget);
    expect(fake.accountSearchQueries, isEmpty);
    expect(
      fake.accountListQueries.where((q) => q.q != null).map((q) => q.q).toSet(),
      {'قديم', 'جديد'},
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
