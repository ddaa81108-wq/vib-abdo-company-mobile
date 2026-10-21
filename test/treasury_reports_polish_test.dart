import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/reports/reports_screen.dart';
import 'package:vib_abdo_company_mobile/features/treasury/treasury_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/export_pdf_button.dart';

import 'support/pump_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('treasury shows server cards, movements, and older pages', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/treasury');

    expectRtl(tester);
    expect(find.byKey(TreasuryScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('treasury-summary')), findsOneWidget);
    expect(find.byKey(const Key('active-cash-card')), findsOneWidget);
    expect(find.text('51,000 د.ل'), findsWidgets);
    expect(find.text('45,000 د.ل'), findsWidgets);
    expect(find.text('12,000 د.ل'), findsWidgets);
    expect(find.text('8,000 د.ل'), findsWidgets);
    expect(find.text('95,000 ج.م'), findsWidgets);
    expect(find.text('9.5'), findsWidgets);
    expect(find.text('10,000 د.ل'), findsWidgets);
    expect(find.text(AppStrings.rateMissing), findsNothing);
    expect(find.text('إيداع تجريبي'), findsOneWidget);
    expect(find.byKey(const Key('cash-in')), findsOneWidget);
    expect(find.byKey(const Key('cash-out')), findsOneWidget);
    expectAmountDirection(tester);

    final card = tester.widget<Card>(find.byKey(const Key('active-cash-card')));
    expect(card.color, AppStatusColors.light.cashPositive);
    expect(card.color, const Color(0xFF087A50));
    final title = tester.widget<Text>(find.text(AppStrings.activeCash));
    expect(title.style?.color, AppStatusColors.light.onStatus);

    expect(find.text('خروج أقدم'), findsNothing);
    await tester.tap(find.byKey(const Key('load-older')));
    await settle(tester);
    expect(find.text('خروج أقدم'), findsOneWidget);
    expect(find.text('7,000 د.ل'), findsWidgets);
    expect(find.byKey(const Key('cash-entry-ce_old')), findsOneWidget);
    expect(find.byKey(const Key('load-older')), findsNothing);
  });

  testWidgets('treasury load older shows the error and retries', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(390, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/treasury');
    (layer.client as FakeApiClient).failOlderRemaining = 1;
    await reveal(
      tester,
      find.byKey(const Key('load-older')),
      TreasuryScreen.screenKey,
    );
    await tester.tap(find.byKey(const Key('load-older')));
    await settle(tester);
    expect(find.byKey(const Key('load-older-error')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsWidgets);
    await tester.tap(find.byKey(const Key('load-older')));
    await settle(tester);
    expect(find.text('خروج أقدم'), findsOneWidget);
    expect(find.byKey(const Key('load-older-error')), findsNothing);
  });

  testWidgets('treasury tone, empty ledger, offline, and hidden writes', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      overrides: [
        treasuryProvider.overrideWith((ref) async {
          return TreasurySummaryDto.fromData({
            'version': 3,
            'totals': {
              'receivablesUnits': 10,
              'liabilitiesUnits': 4,
              'activeCashUnits': 8,
              'netUnits': 14,
              'activeCashTone': 'negative',
            },
          });
        }),
        cashLedgerProvider.overrideWith((ref) async {
          return const Paged<CashEntryDto>(items: <CashEntryDto>[]);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/treasury');

    final negative = tester.widget<Card>(
      find.byKey(const Key('active-cash-card')),
    );
    expect(negative.color, const Color(0xFFB43131));
    expect(negative.color, AppStatusColors.dark.cashNegative);
    expect(find.byKey(const Key('treasury-empty')), findsOneWidget);
    expect(find.byKey(const Key('load-older')), findsNothing);
    expect(find.byKey(const Key('cash-in')), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(HomeShell)))
        .read(onlineProvider.notifier)
        .setOnline(false);
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('cash-in'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('cash-out'))).onPressed,
      isNull,
    );

    final layer = ProviderScope.containerOf(
      tester.element(find.byType(HomeShell)),
    ).read(apiLayerProvider);
    layer.permissions.applyFromServer(
      const ['treasury.read', 'treasury.write'],
      role: 'employee',
      sectionAccess: const {'treasury': 'read'},
    );
    await tester.pump();
    expect(find.byKey(TreasuryScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('cash-in')), findsNothing);
    expect(find.byKey(const Key('cash-out')), findsNothing);

    layer.permissions.applyFromServer(
      const ['treasury.read', 'treasury.write'],
      role: 'employee',
      sectionAccess: const {'treasury': 'manage'},
    );
    ProviderScope.containerOf(tester.element(find.byType(HomeShell)))
        .read(onlineProvider.notifier)
        .setOnline(true);
    await tester.pump();
    expect(find.byKey(const Key('cash-in')), findsOneWidget);
    expect(find.byKey(const Key('cash-out')), findsOneWidget);
  });

  testWidgets('reports stay read-only and switch cards to a scrolling table', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');

    expectRtl(tester);
    expect(find.byKey(ReportsScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('report-cards')), findsOneWidget);
    expect(find.byKey(const Key('report-table')), findsNothing);
    expect(find.byKey(const Key('report-current')), findsOneWidget);
    expect(find.byKey(ExportPdfButton.buttonKey), findsOneWidget);
    expect(find.text(AppStrings.reportsReadOnly), findsOneWidget);
    expect(find.text('51,000 د.ل'), findsWidgets);
    expect(find.text('1,200 د.ل'), findsWidgets);
    expect(find.textContaining('سبب تجريبي'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('cash-in')), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expectAmountDirection(tester);

    for (final width in const [320.0, 360.0, 393.0, 430.0]) {
      tester.view.physicalSize = Size(width, 1800);
      await tester.pump();
      expect(find.byKey(const Key('report-cards')), findsOneWidget);
      expect(find.byKey(const Key('report-table')), findsNothing);
      expect(tester.takeException(), isNull);
    }

    tester.view.physicalSize = const Size(700, 1400);
    await tester.pump();
    expect(find.byKey(const Key('report-table')), findsOneWidget);
    expect(find.byKey(const Key('report-cards')), findsNothing);
    expect(find.text(AppStrings.scrollColumns), findsOneWidget);
    expect(find.text(AppStrings.pinnedColumn), findsOneWidget);
    expect(find.text(AppStrings.netChange), findsWidgets);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('report-table-scroll')),
    );
    expect(scroll.scrollDirection, Axis.horizontal);
    expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
    final before = scroll.controller!.offset;
    await tester.drag(
      find.byKey(const Key('report-table-scroll')),
      const Offset(-160, 0),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('report-table-scroll')),
      const Offset(160, 0),
    );
    await tester.pump();
    expect(scroll.controller!.offset, isNot(before));
    expect(tester.takeException(), isNull);

    final layer = ProviderScope.containerOf(
      tester.element(find.byType(HomeShell)),
    ).read(apiLayerProvider);
    layer.permissions.applyFromServer(
      const ['reports.read', 'reports.write'],
      role: 'admin',
      fullAccess: true,
      sectionAccess: const {'reports': 'manage'},
    );
    await tester.pump();
    expect(find.byKey(ReportsScreen.screenKey), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('cash-in')), findsNothing);
    expect(find.byKey(ExportPdfButton.buttonKey), findsOneWidget);

    layer.permissions.applyFromServer(
      const ['reports.read', 'reports.write'],
      role: 'employee',
      sectionAccess: const {'reports': 'manage'},
    );
    await tester.pump();
    await go(tester, '/reports');
    expect(find.byKey(ReportsScreen.screenKey), findsOneWidget);
    expect(find.byKey(ExportPdfButton.buttonKey), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'report chips keep their colours and missing change stays hidden',
    (tester) async {
      await pumpFakeApp(
        tester,
        size: const Size(393, 1800),
        overrides: [
          reportsProvider.overrideWith((ref) async {
            return ReportsDto.fromData({
              'items': [
                {
                  'sequence': 1,
                  'date': '2026-10-18',
                  'status': 'normal',
                  'netUnits': 1,
                },
                {
                  'sequence': 2,
                  'date': '2026-10-17',
                  'status': 'needs_review',
                  'netUnits': 2,
                },
                {
                  'sequence': 3,
                  'date': '2026-10-16',
                  'status': 'urgent_review',
                  'netUnits': 3,
                },
                {
                  'sequence': 4,
                  'date': '2026-10-15',
                  'status': 'rate_missing',
                  'netUnits': 4,
                },
              ],
            });
          }),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/reports');
      expect(find.text(AppStrings.netChange), findsNothing);
      expectChip(
        tester,
        'normal',
        AppStatusColors.light.chipNormalBg,
        AppStatusColors.light.chipNormalFg,
      );
      expectChip(
        tester,
        'needs_review',
        AppStatusColors.light.chipReviewBg,
        AppStatusColors.light.chipReviewFg,
      );
      expectChip(
        tester,
        'urgent_review',
        AppStatusColors.light.chipCriticalBg,
        AppStatusColors.light.chipCriticalFg,
      );
      expectChip(
        tester,
        'rate_missing',
        AppStatusColors.light.chipCriticalBg,
        AppStatusColors.light.chipCriticalFg,
      );

      tester.view.physicalSize = const Size(800, 1800);
      await tester.pump();
      await tester.tap(find.byTooltip(AppStrings.themeDark));
      await settle(tester);
      expect(
        Theme.of(tester.element(find.byType(ReportsScreen))).brightness,
        Brightness.dark,
      );
      expectChip(
        tester,
        'normal',
        AppStatusColors.dark.chipNormalBg,
        AppStatusColors.dark.chipNormalFg,
      );
      expect(
        AppStatusColors.dark.chipNormalBg,
        AppStatusColors.light.chipNormalBg,
      );
      expect(
        AppStatusColors.dark.chipReviewBg,
        AppStatusColors.light.chipReviewBg,
      );
      expect(
        AppStatusColors.dark.chipCriticalBg,
        AppStatusColors.light.chipCriticalBg,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty reports and a missing treasury rate stay neutral', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1200),
      overrides: [
        reportsProvider.overrideWith((ref) async {
          return ReportsDto.fromData(const {'items': []});
        }),
        treasuryProvider.overrideWith((ref) async {
          return TreasurySummaryDto.fromData({
            'version': 1,
            'totals': {
              'receivablesUnits': 5,
              'activeCashUnits': 1,
              'egyptianSourceUnits': 90,
              'netUnits': 5,
            },
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/reports');
    expect(find.byKey(const Key('reports-empty')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(ExportPdfButton.buttonKey), findsOneWidget);

    await go(tester, '/treasury');
    expect(find.byKey(const Key('rate-missing')), findsOneWidget);
    expect(find.text(AppStrings.rateMissing), findsOneWidget);
    final card = tester.widget<Card>(find.byKey(const Key('active-cash-card')));
    expect(card.color, isNull);
    expect(find.text('90 ج.م'), findsNothing);
  });

  testWidgets('both screens lay out on phones in light and dark', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    const widths = <double>[320, 360, 393, 430];
    const scales = <double>[1, 1.3, 2];

    for (final dark in const [false, true]) {
      if (dark) {
        tester.view.physicalSize = const Size(800, 1600);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await tester.pump();
        await tester.tap(find.byTooltip(AppStrings.themeDark));
        await settle(tester);
      }
      for (final width in widths) {
        for (final scale in scales) {
          tester.view.physicalSize = Size(width, 1700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await go(tester, '/treasury');
          expect(find.byKey(TreasuryScreen.screenKey), findsOneWidget);
          expect(find.byKey(const Key('treasury-summary')), findsOneWidget);
          await reveal(
            tester,
            find.byKey(const Key('cash-in')),
            TreasuryScreen.screenKey,
          );
          await reveal(
            tester,
            find.byKey(const Key('cash-out')),
            TreasuryScreen.screenKey,
          );
          await reveal(
            tester,
            find.byKey(const Key('load-older')),
            TreasuryScreen.screenKey,
          );
          expect(tester.takeException(), isNull);
          expectNoLatin(tester);

          await go(tester, '/reports');
          expect(find.byKey(ReportsScreen.screenKey), findsOneWidget);
          expect(find.byKey(const Key('report-cards')), findsOneWidget);
          expect(find.byKey(const Key('report-table')), findsNothing);
          await reveal(
            tester,
            find.byKey(const Key('reports-refresh')),
            ReportsScreen.screenKey,
          );
          await reveal(
            tester,
            find.byKey(ExportPdfButton.buttonKey),
            ReportsScreen.screenKey,
          );
          await reveal(
            tester,
            find.byKey(const Key('report-card-30')),
            ReportsScreen.screenKey,
          );
          expect(tester.takeException(), isNull);
          expectNoLatin(tester);
        }
      }
    }

    tester.view.physicalSize = const Size(800, 1400);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await go(tester, '/reports');
    expect(find.byKey(const Key('report-table')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await go(tester, '/treasury');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cash form stays reachable at 320 and text scale 2', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(320, 700));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await go(tester, '/treasury');
    await reveal(
      tester,
      find.byKey(const Key('cash-in')),
      TreasuryScreen.screenKey,
    );
    await tester.tap(find.byKey(const Key('cash-in')));
    await settle(tester);
    expect(find.byKey(const Key('save-cash')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('save-cash')));
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byKey(const Key('save-cash')))).pop();
    await settle(tester);
    expect(find.byKey(TreasuryScreen.screenKey), findsOneWidget);
  });
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

void expectAmountDirection(WidgetTester tester) {
  final money = find.byType(MoneyText).first;
  final direction = tester.widget<Directionality>(
    find.descendant(of: money, matching: find.byType(Directionality)),
  );
  expect(direction.textDirection, TextDirection.ltr);
}

void expectChip(
  WidgetTester tester,
  String status,
  Color background,
  Color foreground,
) {
  final chip = find.byKey(Key('report-chip-$status')).first;
  final decoration =
      tester.widget<Container>(chip).decoration! as BoxDecoration;
  expect(decoration.color, background);
  final text = tester.widget<Text>(
    find.descendant(of: chip, matching: find.byType(Text)),
  );
  expect(text.style?.color, foreground);
}

void expectNoLatin(WidgetTester tester) {
  final latin = RegExp(r'[A-Za-z]{4,}');
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data ?? '';
    expect(latin.hasMatch(data), isFalse, reason: data);
  }
}

Future<void> reveal(WidgetTester tester, Finder finder, Key screen) {
  return tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.descendant(
      of: find.byKey(screen),
      matching: find.byType(Scrollable),
    ),
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
