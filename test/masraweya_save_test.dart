import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  test(
    'saveMasraweyaDay stores the day and the provider reads it back',
    () async {
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

      final before = await container.read(masraweyaProvider.future);
      expect(before.previousValueUnits?.units, 10000);
      expect(before.version, 2);

      final saved = await container
          .read(masraweyaActionsProvider)
          .saveDay(
            SaveMasraweyaDayRequest(
              businessDate: before.businessDate,
              previousValueUnits: 1,
              purchasesUnits: before.purchasesUnits?.asInt,
              entries: before.entries,
            ),
            MutationMeta(
              expectedVersion: before.version,
              requestId: 'provider-1',
            ),
          );
      expect(saved.previousValueUnits?.units, 1);
      expect(saved.version, 3);
      expect(saved.purchasesUnits, before.purchasesUnits);
      expect(saved.workTotalUnits, before.workTotalUnits);
      expect(saved.remainingUnits, before.remainingUnits);

      container.invalidate(masraweyaProvider);
      final after = await container.read(masraweyaProvider.future);
      expect(after.previousValueUnits?.units, 1);
      expect(after.purchasesUnits, before.purchasesUnits);
      expect(after.entries.single.valueUnits, before.entries.single.valueUnits);
      expect(after.version, 3);
      expect(after.workTotalUnits, before.workTotalUnits);
      expect(after.remainingUnits, before.remainingUnits);
    },
  );

  testWidgets('the save form is visible only with write permission', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

    expect(find.byKey(MasraweyaScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('edit-masraweya')), findsOneWidget);
    expect(find.byKey(const Key('save-masraweya')), findsNothing);

    await tester.tap(find.byKey(const Key('edit-masraweya')));
    await settle(tester);
    expect(find.byKey(const Key('masraweya-form')), findsOneWidget);
    expect(find.byKey(const Key('save-masraweya')), findsOneWidget);

    layer.permissions.applyFromServer(
      const ['masraweya.read'],
      role: 'employee',
      sectionAccess: const {'masraweya': 'read'},
    );
    await tester.pump();
    expect(find.byKey(MasraweyaScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('masraweya-form')), findsNothing);
    expect(find.byKey(const Key('save-masraweya')), findsNothing);
    expect(find.byKey(const Key('edit-masraweya')), findsNothing);
    expect(find.byKey(const Key('masraweya-previous-field')), findsNothing);

    layer.permissions.applyFromServer(
      const ['masraweya.read', 'masraweya.write'],
      role: 'employee',
      sectionAccess: const {'masraweya': 'manage'},
    );
    await tester.pump();
    expect(find.byKey(const Key('edit-masraweya')), findsOneWidget);

    layer.permissions.applyFromServer(
      const ['masraweya.read', 'masraweya.write'],
      role: 'employee',
      sectionAccess: const {'masraweya': 'read'},
    );
    await tester.pump();
    expect(find.byKey(const Key('edit-masraweya')), findsNothing);
    expect(find.byKey(const Key('save-masraweya')), findsNothing);

    layer.permissions.applyFromServer(
      const ['debts.read'],
      role: 'employee',
      sectionAccess: const {'customerDebts': 'read', 'masraweya': 'none'},
    );
    await tester.pump();
    expect(find.byKey(MasraweyaScreen.screenKey), findsNothing);
    expect(find.byKey(const Key('edit-masraweya')), findsNothing);
    expect(find.byKey(const Key('save-masraweya')), findsNothing);
  });

  testWidgets('saving the day sends raw inputs and refreshes server values', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

    expect(amount(tester, 'masraweya-previous'), '10,000 ج.م');
    expect(amount(tester, 'masraweya-purchases'), '2,000 ج.م');
    expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
    expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');

    await openForm(tester);
    await enterField(tester, const Key('masraweya-previous-field'), '');
    await tester.ensureVisible(find.byKey(const Key('save-masraweya')));
    await tester.tap(find.byKey(const Key('save-masraweya')));
    await tester.pump();
    expect(find.text(AppStrings.integerOnly), findsOneWidget);
    expect(fake.mutationRequestIds, isEmpty);

    await enterField(tester, const Key('masraweya-previous-field'), '1');
    await enterField(tester, const Key('masraweya-purchases-field'), '9');
    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-0'),
      '60',
    );
    await tester.ensureVisible(find.byKey(const Key('save-masraweya')));
    await tester.tap(find.byKey(const Key('save-masraweya')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.saveDayConfirm), findsOneWidget);
    expect(find.text('1 · 9 · 3000 · 60'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await finishSend(tester);

    final body = jsonDecode(fake.mutationBodies.single) as Map<String, dynamic>;
    expect(body['requestId'], isA<String>());
    expect('${body['requestId']}'.isNotEmpty, isTrue);
    expect(body['expectedVersion'], 2);
    expect(body['businessDate'], '2026-10-19');
    expect(body['previousValueUnits'], 1);
    expect(body['purchasesUnits'], 9);
    expect(body.containsKey('workTotalUnits'), isFalse);
    expect(body.containsKey('remainingUnits'), isFalse);
    final entries = body['entries'] as List;
    expect(entries.single['valueUnits'], 3000);
    expect(entries.single['commissionUnits'], 60);
    expect(fake.mutationPaths.single, '/api/masraweya/day');
    expect(find.byKey(const Key('masraweya-form')), findsNothing);
    expect(amount(tester, 'masraweya-previous'), '1 ج.م');
    expect(amount(tester, 'masraweya-purchases'), '9 ج.م');
    expect(amount(tester, 'masraweya-entry-commission-0'), '60 ج.م');
    expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
    expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');
  });

  testWidgets(
    'a failed retry keeps the request id until the inputs or version change',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      await openForm(tester);
      await enterField(tester, const Key('masraweya-previous-field'), '1');
      fake.failMutationsRemaining = 2;

      await confirmSave(tester);
      await finishSend(tester);
      expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
      final first = fake.mutationRequestIds.single;

      await confirmSave(tester);
      await finishSend(tester);
      expect(fake.mutationRequestIds, [first, first]);

      await enterField(tester, const Key('masraweya-previous-field'), '2');
      fake.failMutationsRemaining = 1;
      await confirmSave(tester);
      await finishSend(tester);
      expect(fake.mutationRequestIds, hasLength(3));
      expect(fake.mutationRequestIds[2], isNot(first));
    },
  );

  testWidgets(
    'a version conflict refetches and the next save uses the new version',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      await openForm(tester);

      // Real async: the widget binding otherwise never fires the fake delay
      // while this test is awaiting it.
      await tester.runAsync(
        () => layer.masraweya.saveDay(
          const SaveMasraweyaDayRequest(
            businessDate: '2026-10-19',
            previousValueUnits: 7,
            purchasesUnits: 2000,
            entries: [
              MasraweyaEntryDto(
                valueUnits: MoneyValue.known(3000),
                commissionUnits: MoneyValue.known(50),
              ),
            ],
          ),
          MutationMeta(expectedVersion: 2, requestId: 'other-writer'),
        ),
      );
      expect(amount(tester, 'masraweya-previous'), '10,000 ج.م');

      await enterField(tester, const Key('masraweya-previous-field'), '1');
      await confirmSave(tester);
      await finishSend(tester);

      expect(find.text(AppStrings.versionConflict), findsWidgets);
      expect(amount(tester, 'masraweya-previous'), '7 ج.م');
      expect(find.byKey(const Key('masraweya-form')), findsOneWidget);

      await confirmSave(tester);
      await finishSend(tester);

      expect(amount(tester, 'masraweya-previous'), '1 ج.م');
      expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');
      expect(fake.mutationRequestIds, hasLength(3));
      expect(fake.mutationRequestIds[1], isNot(fake.mutationRequestIds[2]));
      final retry = jsonDecode(fake.mutationBodies[2]) as Map<String, dynamic>;
      expect(retry['expectedVersion'], 3);
      expect(retry['previousValueUnits'], 1);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

String amount(WidgetTester tester, String key) {
  final text = tester.widget<Text>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).last,
  );
  return text.data!;
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('edit-masraweya')));
  await settle(tester);
}

Future<void> enterField(WidgetTester tester, Key key, String value) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> confirmSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('save-masraweya')));
  await tester.tap(find.byKey(const Key('save-masraweya')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const Key('confirm-mutation')));
}

Future<void> finishSend(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
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
