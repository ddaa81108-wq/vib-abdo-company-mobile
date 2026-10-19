import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('retrying an unchanged account form reuses the request id', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    fake.failMutationsRemaining = 1;

    await tester.tap(find.byKey(const Key('add-account')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('create-name')), 'عميل');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pump();
    await tester.pump();

    expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
    expect(find.byKey(const Key('save-account')), findsOneWidget);
    final first = fake.mutationRequestIds.single;

    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pump();
    await tester.pump();

    expect(fake.mutationRequestIds, [first, first]);
  });

  testWidgets('editing the amount or opening a new movement form changes the request id', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    fake.failMutationsRemaining = 2;

    await tester.tap(find.byKey(const Key('add-payment')));
    await settle(tester);
    await enterAmount(tester, '100');
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();
    await tester.pump();
    await enterAmount(tester, '180');
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();
    await tester.pump();

    expect(fake.mutationRequestIds, hasLength(2));
    expect(fake.mutationRequestIds[0], isNot(fake.mutationRequestIds[1]));

    fake.failMutationsRemaining = 0;
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('save-movement')), findsNothing);

    await tester.tap(find.byKey(const Key('add-payment')));
    await settle(tester);
    await enterAmount(tester, '180');
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();
    await tester.pump();

    expect(fake.mutationRequestIds, hasLength(4));
    expect(fake.mutationRequestIds[3], isNot(fake.mutationRequestIds[1]));
  });

  testWidgets('a collection form ignores a second tap while the send is in flight', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    final gate = Completer<void>();
    fake.pauseMutations = gate;

    await tester.tap(find.byKey(const Key('unlinked-collection')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('unlinked-name')), 'عميل');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('unlinked-amount')),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-unlinked')));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byKey(const Key('save-unlinked')));
    expect(button.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('save-unlinked')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('save-unlinked')));
    await tester.pump();
    expect(fake.mutationRequestIds, hasLength(1));

    gate.complete();
    fake.pauseMutations = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.mutationRequestIds, hasLength(1));
  });

  testWidgets('a payment dialog ignores a second confirm while the send is in flight', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    final gate = Completer<void>();
    fake.pauseMutations = gate;

    await tester.tap(find.byKey(const Key('add-payment')));
    await settle(tester);
    await enterAmount(tester, '100');
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byKey(const Key('save-movement')));
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const Key('save-movement')));
    await tester.pump();
    expect(fake.mutationRequestIds, hasLength(1));

    gate.complete();
    fake.pauseMutations = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fake.mutationRequestIds, hasLength(1));
  });

  testWidgets('amount fields explain the minor-unit format', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    await tester.tap(find.byKey(const Key('add-debt')));
    await settle(tester);

    expect(find.text(AppStrings.unitsHint), findsWidgets);
  });
}

Future<void> enterAmount(WidgetTester tester, String value) async {
  await tester.enterText(
    find.descendant(of: find.byKey(const Key('movement-amount')), matching: find.byType(TextField)).hitTestable(),
    value,
  );
  await tester.pump();
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
