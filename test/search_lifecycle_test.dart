import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('a slower search does not replace a newer query', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 900));
    final fake = layer.client as FakeApiClient;
    fake.suggestionItems = [
      {'id': 'old', 'name': 'نتيجة أولى'},
    ];
    final firstSection = Completer<void>();
    final laterSections = Completer<void>();
    fake.pauseSuggestions = firstSection;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/search');

    await tester.enterText(find.byKey(const Key('unified-search')), 'قديم');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    fake.pauseSuggestions = laterSections;
    firstSection.complete();
    await tester.pump();

    fake.suggestionItems = [
      {'id': 'new', 'name': 'نتيجة ثانية'},
    ];
    fake.pauseSuggestions = null;
    await tester.enterText(find.byKey(const Key('unified-search')), 'جديد');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('نتيجة ثانية'), findsWidgets);
    expect(find.text('نتيجة أولى'), findsNothing);

    fake.suggestionItems = [
      {'id': 'old', 'name': 'نتيجة أولى'},
    ];
    laterSections.complete();
    await tester.pumpAndSettle();
    expect(find.text('نتيجة أولى'), findsNothing);
    expect(find.text('نتيجة ثانية'), findsWidgets);
    expect(find.text('جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
