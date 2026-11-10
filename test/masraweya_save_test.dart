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

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
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
      expect(before.editable, isTrue);
      expect(before.today, '2026-10-19');

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
      expect(after.version, 3);
      expect(after.workTotalUnits, before.workTotalUnits);
      expect(after.remainingUnits, before.remainingUnits);
    },
  );

  testWidgets('fields follow masraweya write, not a manual save button', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 956));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

    expect(find.byKey(MasraweyaScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('save-masraweya')), findsNothing);
    expect(find.byKey(const Key('edit-masraweya')), findsNothing);
    expect(find.byKey(const Key('masraweya-form')), findsOneWidget);
    expect(find.byKey(const Key('masraweya-previous-field')), findsOneWidget);
    expect(find.byKey(const Key('masraweya-add-row')), findsOneWidget);
    expect(find.text('٥'), findsNothing);
    expect(find.textContaining('٧ أيام'), findsNothing);

    layer.permissions.applyFromServer(
      const ['masraweya.read'],
      role: 'employee',
      sectionAccess: const {'masraweya': 'read'},
    );
    await tester.pump();
    expect(find.byKey(const Key('masraweya-form')), findsNothing);
    expect(find.byKey(const Key('masraweya-previous-field')), findsNothing);
    expect(find.byKey(const Key('masraweya-add-row')), findsNothing);

    layer.permissions.applyFromServer(
      const ['masraweya.read', 'masraweya.write'],
      role: 'employee',
      sectionAccess: const {'masraweya': 'manage'},
    );
    await tester.pump();
    expect(find.byKey(const Key('masraweya-previous-field')), findsOneWidget);

    layer.permissions.applyFromServer(
      const ['masraweya.read', 'masraweya.write'],
      role: 'employee',
      sectionAccess: const {'masraweya': 'read'},
    );
    await tester.pump();
    expect(find.byKey(const Key('masraweya-previous-field')), findsNothing);
    expect(find.byKey(const Key('masraweya-add-row')), findsNothing);

    layer.permissions.applyFromServer(
      const ['debts.read'],
      role: 'employee',
      sectionAccess: const {'customerDebts': 'read', 'masraweya': 'none'},
    );
    await tester.pump();
    expect(find.byKey(MasraweyaScreen.screenKey), findsNothing);
  });

  testWidgets(
    'leaving a complete row autosaves raw inputs and keeps server totals',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(440, 1200));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');

      expect(fieldDigits(tester, 'masraweya-previous-field'), '10000');
      expect(fieldDigits(tester, 'masraweya-purchases-field'), '2000');
      expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
      expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');

      await enterField(tester, const Key('masraweya-previous-field'), '');
      await leaveFocus(tester);
      expect(fake.mutationRequestIds, isEmpty);
      expect(find.text('القيمة السابقة عدد صحيح.'), findsOneWidget);

      await enterField(tester, const Key('masraweya-previous-field'), '1');
      await enterField(tester, const Key('masraweya-purchases-field'), '9');
      await enterField(
        tester,
        const Key('masraweya-entry-commission-field-0'),
        '60',
      );
      await leaveFocus(tester);

      expect(fake.mutationPaths, isNotEmpty);
      expect(
        fake.mutationPaths.every((path) => path == '/api/masraweya/day'),
        isTrue,
      );
      final last = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(last['expectedVersion'], isA<int>());
      expect(last['businessDate'], '2026-10-19');
      expect(last['previousValueUnits'], 1);
      expect(last['purchasesUnits'], 9);
      expect(last.containsKey('workTotalUnits'), isFalse);
      expect(last.containsKey('remainingUnits'), isFalse);
      final entries = last['entries'] as List;
      expect(entries.single['valueUnits'], 3000);
      expect(entries.single['commissionUnits'], 60);
      expect(fieldDigits(tester, 'masraweya-previous-field'), '1');
      expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
      expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');
      expect(find.text('تم الحفظ'), findsOneWidget);

      final versions = [
        for (final raw in fake.mutationBodies)
          (jsonDecode(raw) as Map<String, dynamic>)['expectedVersion'] as int,
      ];
      expect(versions.first, 2);
      for (var i = 1; i < versions.length; i++) {
        expect(versions[i], versions[i - 1] + 1);
      }
    },
  );

  testWidgets('an empty new row is omitted and a value alone saves', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

    await tester.tap(find.byKey(const Key('masraweya-add-row')));
    await settle(tester);
    expect(
      find.byKey(const Key('masraweya-entry-value-field-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('masraweya-work-table')), findsOneWidget);
    expect(fake.mutationRequestIds, isEmpty);

    await enterField(tester, const Key('masraweya-entry-value-field-1'), '500');
    await leaveFocus(tester);
    expect(fake.mutationRequestIds, isNotEmpty);
    expect(
      find.descendant(
        of: find.byKey(const Key('masraweya-entry-total-1')),
        matching: find.textContaining('500'),
      ),
      findsOneWidget,
    );

    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '10',
    );
    await leaveFocus(tester);
    final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
    final entries = body['entries'] as List;
    expect(entries, hasLength(2));
    expect(entries[1], {'valueUnits': 500, 'commissionUnits': 10});
    expect(body.containsKey('workTotalUnits'), isFalse);
  });

  testWidgets(
    'a failed autosave keeps the request id until the draft changes',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(440, 1200));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      await enterField(tester, const Key('masraweya-previous-field'), '1');
      fake.failMutationsRemaining = 1;
      await leaveFocus(tester);

      expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
      final first = fake.mutationRequestIds.single;
      expect(fieldDigits(tester, 'masraweya-previous-field'), '1');

      await tester.tap(find.byKey(const Key('masraweya-retry-save')));
      await finishSend(tester);
      expect(fake.mutationRequestIds, [first, first]);
      expect(fieldDigits(tester, 'masraweya-previous-field'), '1');
    },
  );

  testWidgets('a version conflict keeps the draft and does not send again', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1400));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

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
    expect(fieldDigits(tester, 'masraweya-previous-field'), '10000');

    await enterField(tester, const Key('masraweya-previous-field'), '1');
    await leaveFocus(tester);

    expect(
      find.text('تعارض النسخة. تعديلك محفوظ ولم يُستبدل.'),
      findsOneWidget,
    );
    expect(fieldDigits(tester, 'masraweya-previous-field'), '1');
    expect(fake.mutationRequestIds, hasLength(2));

    await tester.pump(const Duration(seconds: 1));
    expect(fake.mutationRequestIds, hasLength(2));

    await tester.ensureVisible(find.byKey(const Key('masraweya-send-mine')));
    await tester.tap(find.byKey(const Key('masraweya-send-mine')));
    await finishSend(tester);

    expect(fieldDigits(tester, 'masraweya-previous-field'), '1');
    expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');
    expect(fake.mutationRequestIds, hasLength(3));
    expect(fake.mutationRequestIds[2], isNot(fake.mutationRequestIds[1]));
    final retry = jsonDecode(fake.mutationBodies[2]) as Map<String, dynamic>;
    expect(retry['expectedVersion'], 3);
    expect(retry['previousValueUnits'], 1);
  });

  testWidgets('a row total updates while typing and the server summary stays', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(440, 1200));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

    expect(rowAmount(tester, 0), '3,050 ج.م');
    final rowSymbol = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('masraweya-entry-total-0')),
        matching: find.text('ج.م'),
      ),
    );
    final rowDigits = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('masraweya-entry-total-0')),
        matching: find.text('3,050'),
      ),
    );
    expect(rowSymbol.center.dx, lessThan(rowDigits.center.dx));
    expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
    expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');

    await tester.ensureVisible(find.byKey(const Key('masraweya-add-row')));
    await tester.tap(find.byKey(const Key('masraweya-add-row')));
    await settle(tester);
    expect(rowAmount(tester, 1), '—');

    await enterField(tester, const Key('masraweya-entry-value-field-1'), '10');
    expect(rowAmount(tester, 1), '10 ج.م');
    expect(fake.mutationRequestIds, isEmpty);

    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '0',
    );
    expect(rowAmount(tester, 1), '10 ج.م');
    expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');

    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '5',
    );
    expect(rowAmount(tester, 1), '15 ج.م');

    await enterField(tester, const Key('masraweya-entry-value-field-1'), '0');
    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '0',
    );
    expect(rowAmount(tester, 1), '0 ج.م');

    await enterField(
      tester,
      const Key('masraweya-entry-value-field-1'),
      '1,000',
    );
    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '250',
    );
    expect(rowAmount(tester, 1), '1,250 ج.م');

    await enterField(
      tester,
      const Key('masraweya-entry-value-field-1'),
      '9007199254740993',
    );
    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '1',
    );
    expect(rowAmount(tester, 1), '9,007,199,254,740,994 ج.م');

    await enterField(
      tester,
      const Key('masraweya-entry-value-field-1'),
      '12.5',
    );
    expect(rowAmount(tester, 1), '—');
    await enterField(tester, const Key('masraweya-entry-value-field-1'), '-3');
    expect(rowAmount(tester, 1), '—');
    await enterField(
      tester,
      const Key('masraweya-entry-commission-field-1'),
      '',
    );
    expect(rowAmount(tester, 1), '—');

    expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
    expect(amount(tester, 'masraweya-remaining'), '8,950 ج.م');
    for (final raw in fake.mutationBodies) {
      final body = jsonDecode(raw) as Map<String, dynamic>;
      expect(body.containsKey('workTotalUnits'), isFalse);
      expect(body.containsKey('remainingUnits'), isFalse);
      for (final entry in body['entries'] as List) {
        expect((entry as Map).containsKey('totalUnits'), isFalse);
      }
    }
  });

  testWidgets(
    'older than the server window is read-only and does not propagate',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(440, 956));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      expect(find.text('يوم العمل الحالي'), findsOneWidget);
      expect(dateText(tester), '2026-10-19');

      await tester.tap(find.byKey(const Key('masraweya-date-prev')));
      await settle(tester);
      expect(dateText(tester), '2026-10-18');
      expect(find.byKey(const Key('masraweya-previous-field')), findsNothing);
      expect(
        find.byKey(const Key('masraweya-purchases-field')),
        findsOneWidget,
      );
      expect(find.text('يوم العمل الحالي'), findsNothing);

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const Key('masraweya-date-prev')));
        await settle(tester);
      }
      expect(dateText(tester), '2026-10-11');
      expect(find.byKey(const Key('masraweya-readonly')), findsOneWidget);
      expect(find.byKey(const Key('masraweya-purchases-field')), findsNothing);
      expect(find.byKey(const Key('masraweya-add-row')), findsNothing);
      expect(fake.mutationRequestIds, isEmpty);

      await tester.tap(find.byKey(const Key('masraweya-date-today')));
      await settle(tester);
      expect(dateText(tester), '2026-10-19');
      expect(fieldDigits(tester, 'masraweya-previous-field'), '10000');
      expect(amount(tester, 'masraweya-work-total'), '3,050 ج.م');
    },
  );

  testWidgets('value-only row total preview', (tester) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await tester.runAsync(loadScreenshotFonts);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    await tester.tap(find.byKey(const Key('masraweya-add-row')));
    await settle(tester);
    await enterField(tester, const Key('masraweya-entry-value-field-1'), '500');
    await tester.pump();
    expect(rowAmount(tester, 1), '500 ج.م');
    await saveShot(tester, 'masraweya-value-only-total');
    expect(tester.takeException(), isNull);
  }, tags: const ['screenshots']);
}

String rowAmount(WidgetTester tester, int index) {
  return _shownMoney(tester, find.byKey(Key('masraweya-entry-total-$index')));
}

String amount(WidgetTester tester, String key) {
  return _shownMoney(tester, find.byKey(Key(key)));
}

/// Reads a formatted amount. EGP is two texts, symbol then digits.
String _shownMoney(WidgetTester tester, Finder scope) {
  final texts = tester
      .widgetList<Text>(find.descendant(of: scope, matching: find.byType(Text)))
      .map((text) => text.data)
      .whereType<String>()
      .toList();
  if (texts.contains('ج.م')) {
    final number = texts.lastWhere(
      (text) => RegExp(r'^-?[\d,]+(?:\.\d+)?$').hasMatch(text),
    );
    return '$number ج.م';
  }
  return texts.last;
}

String dateText(WidgetTester tester) {
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(const Key('masraweya-date')),
          matching: find.byType(Text),
        )
        .last,
  );
  return text.data!;
}

String fieldDigits(WidgetTester tester, String key) {
  final field = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(field).controller.text;
}

Future<void> enterField(WidgetTester tester, Key key, String value) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> leaveFocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await finishSend(tester);
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
