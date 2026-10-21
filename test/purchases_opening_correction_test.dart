import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('opening balance renders RTL in light mode', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expectRtl(tester);
    expect(themeOf(tester).brightness, Brightness.light);
    expect(find.byKey(const Key('opening-card')), findsOneWidget);
    expect(find.text(AppStrings.purchaseOpening), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('opening-card')),
        matching: find.textContaining('2,000 د.ل'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('opening-card')),
        matching: find.textContaining('80 ج.م'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('set-opening')), findsOneWidget);
    expect(find.text(AppStrings.correctionClosed), findsOneWidget);
    expect(chipColor(tester, '12'), AppStatusColors.light.chipNormalBg);
    expect(find.byKey(const Key('open-correction-12')), findsNothing);
    expect(find.byKey(const Key('close-correction-12')), findsNothing);

    await tester.tap(find.byKey(const Key('set-opening')));
    await settle(tester);
    expect(
      textDirectionOf(tester, const Key('opening-debt')),
      TextDirection.ltr,
    );
    expect(find.text(AppStrings.noPreview), findsOneWidget);
  });

  testWidgets('opening balance rejects a non-integer and sends nothing', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await openOpening(tester);

    await enterField(tester, const Key('opening-debt'), '');
    await enterField(tester, const Key('opening-vodafone'), '40');
    await tester.tap(find.byKey(const Key('save-opening')));
    await tester.pump();

    expect(find.text(AppStrings.integerOnly), findsOneWidget);
    expect(find.text(AppStrings.openingConfirm), findsNothing);
    expect(fake.mutationRequestIds, isEmpty);

    await enterField(tester, const Key('opening-debt'), '1.5');
    await tester.tap(find.byKey(const Key('save-opening')));
    await tester.pump();
    expect(find.text(AppStrings.integerOnly), findsOneWidget);
    expect(fake.mutationRequestIds, isEmpty);
  });

  testWidgets(
    'opening submit confirms then sends requestId and expectedVersion',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      await openOpening(tester);
      await enterField(tester, const Key('opening-debt'), '1,500');
      await enterField(tester, const Key('opening-vodafone'), '٤٠');

      await tester.tap(find.byKey(const Key('save-opening')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.openingConfirm), findsOneWidget);
      expect(find.text('1500 · 40'), findsOneWidget);

      await tester.tap(find.text(AppStrings.cancel));
      await settle(tester);
      expect(find.text(AppStrings.openingConfirm), findsNothing);
      expect(fake.mutationRequestIds, isEmpty);

      await tester.tap(find.byKey(const Key('save-opening')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await finishSend(tester);

      final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(body['requestId'], isA<String>());
      expect('${body['requestId']}'.isNotEmpty, isTrue);
      expect(body['expectedDayVersion'], 3);
      expect(body['previousDebtUnits'], 1500);
      expect(body['previousVodafoneUnits'], 40);
      expect(fake.mutationPaths.last, '/api/purchases/al_bayan/opening');
      expect(find.text(AppStrings.openingConfirm), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('opening-card')),
          matching: find.textContaining('1,500 د.ل'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('opening-card')),
          matching: find.textContaining('40 ج.م'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('سمسم sends the opening write to the simsim ledger', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1600));
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.tap(find.text(AppStrings.simsim));
    await settle(tester);
    await openOpening(tester);
    await tester.tap(find.byKey(const Key('save-opening')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await finishSend(tester);
    final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
    expect(body['requestId'], isNotEmpty);
    expect(body['expectedDayVersion'], 3);
    expect(fake.mutationPaths.last, '/api/purchases/simsim/opening');
  });

  testWidgets('a server opening object supplies the version that is sent', (
    tester,
  ) async {
    final layer = await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return PurchasesBookPage.fromData({
            'opening': {
              'previousDebtUnits': 7,
              'previousVodafoneUnits': 8,
              'version': 11,
            },
            'days': [
              {
                'day': '1',
                'version': 3,
                'status': 'draft',
                'entries': [],
                'totals': {
                  'previousDebtUnits': 99,
                  'previousVodafoneUnits': 99,
                },
              },
            ],
          });
        }),
      ],
    );
    final fake = layer.client as FakeApiClient;
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(
      find.descendant(
        of: find.byKey(const Key('opening-card')),
        matching: find.textContaining('7 د.ل'),
      ),
      findsOneWidget,
    );
    await openOpening(tester);
    await tester.tap(find.byKey(const Key('save-opening')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-mutation')));
    await finishSend(tester);
    final body = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
    expect(body['expectedDayVersion'], 11);
    expect(body['previousDebtUnits'], 7);
    expect(body['previousVodafoneUnits'], 8);
    expect(body['requestId'], isNotEmpty);
  });

  testWidgets(
    'opening conflict shows the Arabic reload message and refetches',
    (tester) async {
      var loads = 0;
      final layer = await pumpFakeApp(
        tester,
        size: const Size(800, 1600),
        overrides: [
          purchasesProvider.overrideWith((ref) async {
            loads++;
            return PurchasesBookPage.fromData({
              'days': [
                {
                  'day': '9',
                  'version': -1,
                  'status': 'draft',
                  'entries': [],
                  'totals': {
                    'previousDebtUnits': 10,
                    'previousVodafoneUnits': 2,
                  },
                },
              ],
            });
          }),
        ],
      );
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      final before = loads;
      await openOpening(tester);
      await tester.tap(find.byKey(const Key('save-opening')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);

      expect(find.text(AppStrings.versionConflict), findsWidgets);
      expect(loads, greaterThan(before));
      final first = fake.mutationRequestIds.single;

      await tester.tap(find.byKey(const Key('save-opening')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);
      expect(fake.mutationRequestIds, [first, first]);

      await enterField(tester, const Key('opening-debt'), '11');
      await tester.tap(find.byKey(const Key('save-opening')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);
      expect(fake.mutationRequestIds, hasLength(3));
      expect(fake.mutationRequestIds[2], isNot(first));
    },
  );

  testWidgets(
    'day correction renders open and closed, and confirms the write',
    (tester) async {
      final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
      final fake = layer.client as FakeApiClient;
      fake.purchaseFixtureStatus = 'finalized';
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');

      expectRtl(tester);
      expect(find.text(AppStrings.correctionClosed), findsOneWidget);
      expect(find.text(AppStrings.correctionOpen), findsNothing);
      expect(find.byKey(const Key('open-correction-12')), findsOneWidget);
      expect(find.byKey(const Key('close-correction-12')), findsNothing);
      expect(chipColor(tester, '12'), AppStatusColors.light.chipNormalBg);

      await tester.tap(find.byKey(const Key('open-correction-12')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.openCorrectionConfirm), findsOneWidget);
      await tester.tap(find.text(AppStrings.cancel));
      await tester.pump();
      expect(fake.mutationRequestIds, isEmpty);
      expect(find.text(AppStrings.correctionClosed), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-correction-12')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await finishSend(tester);

      final opened = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(opened['requestId'], isNotEmpty);
      expect(opened['expectedDayVersion'], 3);
      expect(opened['open'], isTrue);
      expect(
        fake.mutationPaths.last,
        '/api/purchases/al_bayan/days/12/correction',
      );
      expect(find.text(AppStrings.correctionOpen), findsWidgets);
      expect(find.byKey(const Key('close-correction-12')), findsOneWidget);
      expect(find.byKey(const Key('open-correction-12')), findsNothing);
      expect(chipColor(tester, '12'), AppStatusColors.light.chipReviewBg);

      await tester.tap(find.byKey(const Key('close-correction-12')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.closeCorrectionConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await finishSend(tester);
      final closed = jsonDecode(fake.mutationBodies.last) as Map<String, dynamic>;
      expect(closed['requestId'], isNotEmpty);
      expect(closed['expectedDayVersion'], 3);
      expect(closed['open'], isFalse);
      expect(closed['requestId'], isNot(opened['requestId']));
      expect(find.text(AppStrings.correctionClosed), findsOneWidget);
      expect(find.byKey(const Key('open-correction-12')), findsOneWidget);
    },
  );

  testWidgets(
    'day correction conflict reloads the ledger and a server error does not',
    (tester) async {
      var loads = 0;
      final layer = await pumpFakeApp(
        tester,
        size: const Size(800, 1600),
        overrides: [
          purchasesProvider.overrideWith((ref) async {
            loads++;
            return PurchasesBookPage.fromData({
              'days': [
                {
                  'day': '12',
                  'version': -1,
                  'status': 'finalized',
                  'entries': [],
                  'totals': {'previousDebtUnits': 1},
                },
              ],
            });
          }),
        ],
      );
      final fake = layer.client as FakeApiClient;
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');
      final before = loads;
      await tester.tap(find.byKey(const Key('open-correction-12')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.openCorrectionConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);
      expect(find.text(AppStrings.versionConflict), findsWidgets);
      expect(loads, greaterThan(before));
      expect(find.byKey(const Key('open-correction-12')), findsOneWidget);

      fake.failMutationsRemaining = 1;
      final afterConflict = loads;
      await tester.tap(find.byKey(const Key('open-correction-12')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-mutation')));
      await settle(tester);
      expect(find.text('تعذر تنفيذ الطلب.'), findsWidgets);
      expect(loads, afterConflict);
    },
  );

  testWidgets('opening and correction stay hidden without their permissions', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 1800));
    final fake = layer.client as FakeApiClient;
    fake.purchaseFixtureStatus = 'correction';
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(find.byKey(const Key('set-opening')), findsOneWidget);
    expect(find.byKey(const Key('close-correction-12')), findsOneWidget);

    layer.permissions.applyFromServer(
      const ['purchases.read', 'purchases.write', 'purchases.finalize'],
      role: 'employee',
      sectionAccess: const {'purchases': 'read'},
    );
    await tester.pump();
    expect(find.byKey(PurchasesScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('opening-card')), findsOneWidget);
    expect(find.text(AppStrings.correctionOpen), findsWidgets);
    expect(find.byKey(const Key('set-opening')), findsNothing);
    expect(find.byKey(const Key('close-correction-12')), findsNothing);
    expect(find.byKey(const Key('open-correction-12')), findsNothing);
    expect(find.byKey(const Key('add-purchase-12')), findsNothing);

    layer.permissions.applyFromServer(
      const ['purchases.read', 'purchases.write'],
      role: 'employee',
      sectionAccess: const {'purchases': 'manage'},
    );
    await tester.pump();
    expect(find.byKey(const Key('set-opening')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('set-opening')))
          .onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('close-correction-12')), findsNothing);
    expect(find.byKey(const Key('finalize-day-12')), findsNothing);

    layer.permissions.applyFromServer(
      const ['purchases.read', 'purchases.finalize'],
      role: 'employee',
      sectionAccess: const {'purchases': 'manage'},
    );
    await tester.pump();
    expect(find.byKey(const Key('set-opening')), findsNothing);
    expect(find.byKey(const Key('close-correction-12')), findsNothing);

    layer.permissions.applyFromServer(
      const ['debts.read'],
      role: 'employee',
      sectionAccess: const {'customerDebts': 'read', 'purchases': 'none'},
    );
    await tester.pump();
    expect(find.byKey(PurchasesScreen.screenKey), findsNothing);
    expect(find.byKey(const Key('set-opening')), findsNothing);
    expect(find.byKey(const Key('close-correction-12')), findsNothing);
  });

  testWidgets('correction chips follow light and dark theme tokens', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(800, 1800),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return _constBook(
            days: const [_Day('1', 'finalized'), _Day('2', 'correction')],
          );
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(themeOf(tester).brightness, Brightness.light);
    expectRtl(tester);
    expect(chipColor(tester, '1'), AppStatusColors.light.chipNormalBg);
    expect(chipColor(tester, '2'), AppStatusColors.light.chipReviewBg);
    expect(find.byKey(const Key('open-correction-1')), findsOneWidget);
    expect(find.byKey(const Key('close-correction-2')), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await settle(tester);
    expect(themeOf(tester).brightness, Brightness.dark);
    expectRtl(tester);
    expect(chipColor(tester, '1'), AppStatusColors.dark.chipNormalBg);
    expect(chipColor(tester, '2'), AppStatusColors.dark.chipReviewBg);
    expect(
      themeOf(tester).scaffoldBackgroundColor,
      buildAppTheme(Brightness.dark).scaffoldBackgroundColor,
    );
  });

  testWidgets('opening and correction fit a 320dp phone at 1.3 text', (
    tester,
  ) async {
    await exercisePhone(tester, const Size(320, 800), dark: false);
  });

  testWidgets(
    'opening and correction fit a 430dp phone at 1.3 text in the dark',
    (tester) async {
      await exercisePhone(tester, const Size(430, 900), dark: true);
    },
  );

  for (final scale in const <double>[1.3, 2]) {
    testWidgets('opening balance wraps at 320 dp and text scale $scale', (
      tester,
    ) async {
      await pumpScaled(tester, size: const Size(320, 900), textScale: scale);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/purchases');

      expect(textScaleOf(tester), scale);
      expect(tester.takeException(), isNull);
      final card = find.byKey(const Key('opening-card'));
      final cardRect = tester.getRect(card);
      for (final sample in ['2,000', '80']) {
        final figure = find.descendant(
          of: card,
          matching: find.textContaining(sample),
        );
        expect(figure, findsOneWidget);
        final text = tester.widget<Text>(figure);
        expect(text.maxLines, anyOf(isNull, greaterThan(1)));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.overflow, isNot(TextOverflow.fade));
        expect(text.softWrap, isNot(false));
        final rect = tester.getRect(figure);
        expect(rect.left, greaterThanOrEqualTo(cardRect.left - 1));
        expect(rect.right, lessThanOrEqualTo(cardRect.right + 1));
        expect(rect.top, greaterThanOrEqualTo(cardRect.top - 1));
        expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom + 1));
        expect(rect.width, greaterThan(8));
        expect(rect.height, greaterThan(8));
      }
    });
  }

  testWidgets('add and finalize keys are unique per day', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1100),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return _constBook(
            days: const [_Day('1', 'draft'), _Day('2', 'draft')],
          );
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('add-purchase-1')), findsOneWidget);
    expect(find.byKey(const Key('add-purchase-2')), findsOneWidget);
    expect(find.byKey(const Key('finalize-day-1')), findsOneWidget);
    expect(find.byKey(const Key('finalize-day-2')), findsOneWidget);
    expect(find.byKey(const Key('add-purchase')), findsNothing);
    expect(find.byKey(const Key('finalize-day')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screenshots of opening and correction in light and dark', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(320, 900),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return _constBook(
            days: const [_Day('1', 'finalized'), _Day('2', 'correction')],
          );
        }),
      ],
    );
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await capturePurchases(tester, 'light-small');

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    await settle(tester);
    await capturePurchases(tester, 'light-large');

    await go(tester, '/account');
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await go(tester, '/purchases');
    await capturePurchases(tester, 'dark-large');

    tester.view.physicalSize = const Size(320, 900);
    await settle(tester);
    await capturePurchases(tester, 'dark-small');
  });
}

class _Day {
  const _Day(this.id, this.status);
  final String id;
  final String status;
}

PurchasesBookPage _constBook({required List<_Day> days}) {
  return PurchasesBookPage.fromData({
    'days': [
      for (final day in days)
        {
          'day': day.id,
          'version': 3,
          'status': day.status,
          'entries': <Map<String, dynamic>>[],
          'totals': {
            'previousDebtUnits': 2000,
            'previousVodafoneUnits': 80,
            'todayResultUnits': 1053,
            'todayPaidUnits': 500,
            'totalDebtUnits': 2553,
            'vodafoneRemainingUnits': 0,
          },
        },
    ],
    'lifetimeTotals': {
      'resultUnits': 50000,
      'paidUnits': 47447,
      'remainingUnits': 2553,
    },
  });
}

Future<void> pumpScaled(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.3,
  List<Override> overrides = const [],
}) async {
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpFakeApp(
    tester,
    size: size,
    textScale: textScale,
    overrides: overrides,
  );
}

ThemeData themeOf(WidgetTester tester) {
  return Theme.of(tester.element(find.byKey(PurchasesScreen.screenKey)));
}

void expectRtl(WidgetTester tester) {
  expect(
    Directionality.of(tester.element(find.byKey(PurchasesScreen.screenKey))),
    TextDirection.rtl,
  );
}

double textScaleOf(WidgetTester tester) {
  return MediaQuery.textScalerOf(
    tester.element(find.byKey(PurchasesScreen.screenKey)),
  ).scale(1);
}

TextDirection textDirectionOf(WidgetTester tester, Key key) {
  return tester
      .widget<TextField>(
        find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      )
      .textDirection!;
}

Color? chipColor(WidgetTester tester, String day) {
  final box = tester.widget<Container>(
    find.byKey(Key('correction-status-$day')),
  );
  return (box.decoration! as BoxDecoration).color;
}

Future<void> enterField(WidgetTester tester, Key key, String value) async {
  await tester.enterText(
    find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
    value,
  );
  await tester.pump();
}

Future<void> openOpening(WidgetTester tester) async {
  await show(tester, find.byKey(const Key('set-opening')));
  await tester.tap(find.byKey(const Key('set-opening')));
  await settle(tester);
}

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(
      of: find.byKey(PurchasesScreen.screenKey),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump();
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

Future<void> loadScreenshotFonts() async {
  await _loadFont('assets/fonts/Cairo-Variable.ttf', 'Cairo');
  await _loadFont('assets/fonts/JetBrainsMono-Bold.ttf', 'JetBrainsMono');
  await _loadFont('assets/fonts/JetBrainsMono-ExtraBold.ttf', 'JetBrainsMono');
  final icons = _materialIconsFile();
  if (icons != null) {
    await ui.loadFontFromList(
      await icons.readAsBytes(),
      fontFamily: 'MaterialIcons',
    );
  }
}

Future<void> _loadFont(String path, String family) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await ui.loadFontFromList(await file.readAsBytes(), fontFamily: family);
}

File? _materialIconsFile() {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final candidate = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  if (candidate.existsSync()) return candidate;
  return null;
}

Future<void> capturePurchases(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  final boundaries = tester.allRenderObjects
      .whereType<RenderRepaintBoundary>()
      .where((boundary) => boundary.hasSize && boundary.size.isFinite)
      .toList();
  RenderRepaintBoundary? match;
  for (final boundary in boundaries) {
    final close =
        (boundary.size.width - view.width).abs() < 2 &&
        (boundary.size.height - view.height).abs() < 2;
    if (close) match = boundary;
  }
  final boundary = match ?? boundaries.first;
  final image = await boundary.toImage();
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '/opt/cursor/artifacts/purchases-opening-correction/$name.png',
    );
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } on FileSystemException {
      // The artifact directory exists for this agent, not in CI.
    }
  });
}

Future<void> exercisePhone(
  WidgetTester tester,
  Size size, {
  required bool dark,
}) async {
  await pumpScaled(
    tester,
    size: size,
    overrides: [
      purchasesProvider.overrideWith((ref) async {
        return _constBook(
          days: const [_Day('1', 'finalized'), _Day('2', 'correction')],
        );
      }),
    ],
  );
  if (dark) {
    await tester.tap(find.byKey(const Key('login-theme')));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await signIn(tester, username: 'admin.demo', password: 'demo-only');
  await go(tester, '/purchases');

  expect(textScaleOf(tester), 1.3);
  expectRtl(tester);
  expect(themeOf(tester).brightness, dark ? Brightness.dark : Brightness.light);
  expect(tester.takeException(), isNull);

  await show(tester, find.byKey(const Key('set-opening')));
  await tester.tap(find.byKey(const Key('set-opening')));
  await settle(tester);
  expect(find.byKey(const Key('save-opening')), findsOneWidget);
  expect(tester.takeException(), isNull);

  await tester.ensureVisible(find.byKey(const Key('save-opening')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('save-opening')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text(AppStrings.openingConfirm), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.tap(find.text(AppStrings.cancel));
  await tester.pump(const Duration(milliseconds: 400));
  Navigator.of(tester.element(find.byKey(const Key('save-opening')))).pop();
  await tester.pump(const Duration(milliseconds: 400));

  await show(tester, find.byKey(const Key('open-correction-1')));
  final colors = dark ? AppStatusColors.dark : AppStatusColors.light;
  expect(chipColor(tester, '1'), colors.chipNormalBg);
  expect(chipColor(tester, '2'), colors.chipReviewBg);
  await tester.tap(find.byKey(const Key('open-correction-1')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text(AppStrings.openCorrectionConfirm), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.tap(find.text(AppStrings.cancel));
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
}
