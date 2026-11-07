import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('a failed older audit page keeps the rows and can be retried', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    fake.scriptedGetJson['/api/audit-log'] = jsonEncode({
      'items': [
        {
          'id': 20,
          'action': 'collection.approve',
          'outcome': 'success',
          'actorName': 'مدير تجريبي',
          'createdAt': '2026-10-22T22:00:00.000Z',
        },
      ],
      'nextBefore': 15,
    });
    fake.auditOlderPages['15'] = {
      'items': [
        {'id': 20, 'action': 'collection.approve', 'outcome': 'success'},
        {
          'id': 15,
          'action': 'collection.unlinked.submit',
          'outcome': 'success',
        },
      ],
      'nextBefore': null,
    };
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/settings/audit');
    expect(find.byKey(const Key('audit-event-20')), findsOneWidget);
    fake.failOlderRemaining = 1;
    await tester.tap(find.byKey(const Key('audit-older')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audit-older-error')), findsOneWidget);
    expect(find.byKey(const Key('audit-event-20')), findsOneWidget);
    expect(find.byKey(const Key('audit-event-15')), findsNothing);

    await tester.tap(find.byKey(const Key('audit-older')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audit-event-20')), findsOneWidget);
    expect(find.byKey(const Key('audit-event-15')), findsOneWidget);
    expect(find.byKey(const Key('audit-older-error')), findsNothing);
    expect(find.byKey(const Key('audit-older')), findsNothing);
  });
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle();
}
