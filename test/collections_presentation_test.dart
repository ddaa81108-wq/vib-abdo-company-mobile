import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('each fake role only sees the collections actions it may use', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    // 537f073 admin: decide, cash, link from candidates, close. No receipt
    // buttons: the server refuses an admin's submit and standalone receipt.
    // Ali's layout: filter card, summary, tabs; payroll behind its button.
    expect(find.byKey(const Key('collections-filter-card')), findsOneWidget);
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    await expectPayroll(tester, AppStrings.payroll, AppStrings.myPayroll);
    await expectPresent(tester, const [
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('cash-sb_2'),
      Key('close-batch'),
      Key('unlinked-link-ur_1'),
      Key('unlinked-new-ur_1'),
      Key('unlinked-reject-ur_1'),
    ]);
    for (final key in const [
      Key('submit-as_1'),
      Key('full-as_1'),
      Key('unlinked-collection'),
      Key('unlinked-approve-ur_1'),
      Key('unlinked-cash-ur_1'),
      Key('unlinked-card-ur_2'),
    ]) {
      expect(find.byKey(key, skipOffstage: false), findsNothing);
    }

    await relog(tester, 'limited.admin.demo');
    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    await expectPayroll(tester, AppStrings.myPayroll, AppStrings.payroll);
    await expectPresent(tester, const [
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('unlinked-link-ur_1'),
      Key('unlinked-new-ur_1'),
      Key('unlinked-reject-ur_1'),
    ]);
    expect(
      find.byKey(const Key('cash-sb_2'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('close-batch'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('awaiting-cash-sb_2'), skipOffstage: false),
      findsOneWidget,
    );

    await relog(tester, 'employee.demo');
    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    expect(find.byKey(const Key('collections-filter-card')), findsNothing);
    await expectPayroll(tester, AppStrings.myPayroll, AppStrings.payroll);
    await expectPresent(tester, const [
      Key('full-as_1'),
      Key('submit-as_1'),
      Key('call-as_1'),
      Key('unlinked-collection'),
    ]);
    for (final key in const [
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('cash-sb_2'),
      Key('close-batch'),
      Key('unlinked-link-ur_1'),
      Key('unlinked-new-ur_1'),
      Key('unlinked-reject-ur_1'),
      Key('assignment-as_9'),
    ]) {
      expect(find.byKey(key, skipOffstage: false), findsNothing);
    }
    // as_2 holds a pending receipt: one pending per card, both buttons off.
    await reveal(tester, const Key('submit-as_2'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit-as_2')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('full-as_2'))).onPressed,
      isNull,
    );

    await relog(tester, 'flag.admin.demo');
    await go(tester, '/collections');
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    expect(find.byKey(CollectionsScreen.screenKey), findsNothing);
    expect(find.byKey(const Key('submit-as_1')), findsNothing);

    await relog(tester, 'guest.demo');
    await go(tester, '/collections');
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    expect(find.byKey(CollectionsScreen.screenKey), findsNothing);
    expect(find.byKey(const Key('unlinked-collection')), findsNothing);
  });

  testWidgets(
    'light and dark keep the server tones, RTL, and amount direction',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(360, 1600));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      await expectTheme(tester, Brightness.light, 360);

      await go(tester, '/account');
      await tester.tap(find.byKey(const Key('theme-switch')));
      await settle(tester);
      await go(tester, '/collections');
      tester.view.physicalSize = const Size(430, 1600);
      await settle(tester);
      await expectTheme(tester, Brightness.dark, 430);
    },
  );

  testWidgets(
    'receipt cards do not overflow across phone widths and text scales',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(430, 900));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      Future<void> sweep(List<Key> keys, {Key? unlinkedTab}) async {
        for (final width in const [320.0, 360.0, 393.0, 430.0]) {
          for (final scale in const [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await go(tester, '/collections');
            expect(tester.takeException(), isNull);
            expect(
              Directionality.of(
                tester.element(find.byKey(CollectionsScreen.screenKey)),
              ),
              TextDirection.rtl,
            );
            expectAppBarTitleFits(tester, width);
            await scrollEntireList(tester);
            for (final key in keys) {
              await expectFits(tester, key, width);
            }
            await reveal(tester, const Key('assignment-as_1'));
            expectAmountInside(tester, const Key('assignment-as_1'), '320 د.ل');
            await reveal(tester, const Key('submission-sb_2'));
            expectAmountInside(tester, const Key('submission-sb_2'), '250 د.ل');
            if (unlinkedTab != null) {
              await reveal(tester, unlinkedTab);
              await tester.tap(find.byKey(unlinkedTab));
              await settle(tester);
            }
            await reveal(tester, const Key('unlinked-card-ur_1'));
            expectAmountInside(
              tester,
              const Key('unlinked-card-ur_1'),
              '50 د.ل',
            );
            if (unlinkedTab != null) {
              const cards = Key('collections-tab-cards');
              await reveal(tester, cards);
              await tester.tap(find.byKey(cards));
              await settle(tester);
            }
          }
        }
      }

      await sweep(const [
        Key('approve-sb_1'),
        Key('reject-sb_1'),
        Key('cash-sb_2'),
        Key('close-batch'),
        Key('unlinked-link-ur_1'),
        Key('unlinked-reject-ur_1'),
      ]);
      await relog(tester, 'employee.demo');
      // The employee's standalone receipts are on «تحصيلاتي».
      await sweep(const [
        Key('full-as_1'),
        Key('submit-as_1'),
        Key('call-as_1'),
        Key('unlinked-collection'),
      ], unlinkedTab: const Key('collections-tab-receipts'));
    },
  );

  testWidgets(
    'the unlinked and partial forms stay inside a narrow large-text sheet',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(320, 700));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await signIn(tester, username: 'employee.demo', password: 'demo-only');
      await go(tester, '/collections');

      await reveal(tester, const Key('unlinked-collection'));
      await tester.tap(find.byKey(const Key('unlinked-collection')));
      await settle(tester);
      expect(find.byKey(const Key('unlinked-name')), findsOneWidget);
      expect(find.byKey(const Key('save-unlinked')), findsOneWidget);
      expectFitsBox(tester, const Key('save-unlinked'), 320);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byKey(const Key('unlinked-name')), findsNothing);

      await reveal(tester, const Key('submit-as_1'));
      await tester.tap(find.byKey(const Key('submit-as_1')));
      await settle(tester);
      expect(find.byKey(const Key('partial-form')), findsOneWidget);
      expect(find.byKey(const Key('assignment-amount')), findsOneWidget);
      expectFitsBox(tester, const Key('save-assignment'), 320);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty, loading, payroll error, and offline stay consistent', (
    tester,
  ) async {
    final gate = Completer<CollectionsOverviewDto>();
    final link = ToggleConnectivity(true);
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      connectivity: link,
      overrides: [
        collectionsProvider.overrideWith((ref) => gate.future),
        payrollProvider.overrideWith((ref) async {
          throw const NetworkException();
        }),
      ],
    );
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-loading')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);

    gate.complete(_emptyOverview);
    await settle(tester);
    expect(find.byKey(const Key('collections-loading')), findsNothing);
    expect(
      find.byKey(const Key('collections-empty-assignments')),
      findsOneWidget,
    );
    expect(find.text('لا توجد كروت موجهة حاليًا.'), findsOneWidget);
    expect(find.byKey(const Key('close-batch')), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    // Payroll opens from the bar; its failure shows a retry there.
    await tester.tap(find.byKey(const Key('collections-payroll')));
    await settle(tester);
    expect(find.byKey(const Key('payroll-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('collections-payroll-back')));
    await settle(tester);

    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text(AppStrings.offline), findsWidgets);
    final unlinked = tester.widget<OutlinedButton>(
      find.byKey(const Key('unlinked-collection')),
    );
    expect(unlinked.onPressed, isNull);
    expect(find.byKey(const Key('unlinked-collection')), findsOneWidget);

    link.setOnline(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('unlinked-collection')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'an approved unlinked receipt shows its cash state, no decision',
    (tester) async {
      await pumpFakeApp(
        tester,
        size: const Size(360, 900),
        overrides: [
          collectionsProvider.overrideWith(
            (ref) async => const CollectionsOverviewDto(
              assignments: [],
              submissions: [],
              unlinkedReceipts: [
                UnlinkedReceiptDto(
                  id: 'ur_ok',
                  customerName: 'استلام معتمد تجريبي',
                  amountUnits: MoneyValue.known(15),
                  status: 'approved',
                ),
              ],
              employeeTotals: [],
            ),
          ),
        ],
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/collections');
      expect(find.byKey(const Key('unlinked-card-ur_ok')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('unlinked-card-ur_ok')),
          matching: find.text('15 د.ل'),
        ),
        findsOneWidget,
      );
      expect(find.text('تم الربط والاعتماد'), findsOneWidget);
      expect(find.byKey(const ValueKey('awaiting-cash-ur_ok')), findsOneWidget);
      expect(find.byKey(const Key('unlinked-cash-ur_ok')), findsOneWidget);
      expect(find.byKey(const Key('unlinked-link-ur_ok')), findsNothing);
      expect(find.byKey(const Key('unlinked-reject-ur_ok')), findsNothing);
    },
  );

  testWidgets('screenshots of light and dark at 360 and 430', (tester) async {
    await pumpFakeApp(tester, size: const Size(360, 844));
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    await tester.pump();
    await capture(tester, 'collections-light-360');

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    await settle(tester);
    await capture(tester, 'collections-light-430');

    await go(tester, '/account');
    await tester.tap(find.byKey(const Key('theme-switch')));
    await settle(tester);
    await go(tester, '/collections');
    await capture(tester, 'collections-dark-430');

    tester.view.physicalSize = const Size(360, 844);
    await settle(tester);
    await capture(tester, 'collections-dark-360');
  });
}

const _emptyOverview = CollectionsOverviewDto(
  assignments: [],
  submissions: [],
  unlinkedReceipts: [],
  employeeTotals: [],
);

Future<void> expectTheme(
  WidgetTester tester,
  Brightness brightness,
  double width,
) async {
  final screen = tester.element(find.byKey(CollectionsScreen.screenKey));
  expect(Directionality.of(screen), TextDirection.rtl);
  expect(Theme.of(screen).brightness, brightness);
  // Card tones from the server fields (537f073 collectionCardTone):
  // as_1 untouched → base; as_2 latest partial → yellow.
  await reveal(tester, const Key('assignment-as_1'));
  expect(find.byKey(const Key('tone-as_1-base')), findsOneWidget);
  await reveal(tester, const Key('assignment-as_2'));
  expect(find.byKey(const Key('tone-as_2-yellow')), findsOneWidget);
  await reveal(tester, const Key('awaiting-cash-sb_2'));
  final label = find.descendant(
    of: find.byKey(const ValueKey('awaiting-cash-sb_2')),
    matching: find.byType(Text),
  );
  expect(tester.widget<Text>(label).data, 'ينتظر استلام النقدية');
  expectAmountInside(tester, const Key('submission-sb_2'), '250 د.ل');
  await expectFits(tester, const Key('cash-sb_2'), width);
  await reveal(tester, const Key('unlinked-card-ur_1'));
  expect(find.byKey(const Key('unlinked-card-ur_2')), findsNothing);
  expect(tester.takeException(), isNull);
}

void expectAmountInside(WidgetTester tester, Key cardKey, String amount) {
  final card = tester.getRect(find.byKey(cardKey));
  final figure = find.descendant(
    of: find.byKey(cardKey),
    matching: find.text(amount),
  );
  expect(figure, findsOneWidget);
  final rect = tester.getRect(figure);
  expect(rect.width, greaterThan(0));
  expect(rect.height, greaterThan(0));
  expect(rect.left, greaterThanOrEqualTo(card.left - 1));
  expect(rect.right, lessThanOrEqualTo(card.right + 1));
  expect(card.right - rect.right, lessThan(card.width / 2));
  expect(Directionality.of(tester.element(figure)), TextDirection.ltr);
}

/// Payroll sits behind «المرتبات»: [heading] shows there, [other] never.
Future<void> expectPayroll(
  WidgetTester tester,
  String heading,
  String other,
) async {
  await reveal(tester, const Key('collections-payroll'));
  await tester.tap(find.byKey(const Key('collections-payroll')));
  await settle(tester);
  expect(
    find.descendant(
      of: find.byType(CollectionsHeading),
      matching: find.text(heading),
    ),
    findsOneWidget,
  );
  expect(find.text(other), findsNothing);
  await tester.tap(find.byKey(const Key('collections-payroll-back')));
  await settle(tester);
  expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
}

Future<void> expectPresent(WidgetTester tester, List<Key> keys) async {
  for (final key in keys) {
    await reveal(tester, key);
    expect(find.byKey(key), findsOneWidget);
  }
}

Future<void> expectFits(WidgetTester tester, Key key, double width) async {
  await reveal(tester, key);
  expectFitsBox(tester, key, width);
  expect(tester.takeException(), isNull);
}

void expectAppBarTitleFits(WidgetTester tester, double width) {
  const titleText = 'استلامات الديون';
  final title = find.descendant(
    of: find.byType(AppBar),
    matching: find.text(titleText),
  );
  expect(title, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(title);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.text.toPlainText(), titleText);
  final fitted = tester.renderObject<RenderFittedBox>(
    find.ancestor(of: title, matching: find.byType(FittedBox)),
  );
  final rect = tester.getRect(
    find.ancestor(of: title, matching: find.byType(FittedBox)),
  );
  expect(rect.left, greaterThanOrEqualTo(-1));
  expect(rect.right, lessThanOrEqualTo(width + 1));
  expect(rect.width, greaterThan(24));
  expect(fitted.size.width, lessThanOrEqualTo(width));
  expect(find.byKey(HomeShell.logoutKey), findsOneWidget);
  expect(find.byTooltip(AppStrings.search), findsOneWidget);
}

void expectFitsBox(WidgetTester tester, Key key, double width) {
  final rect = tester.getRect(find.byKey(key));
  expect(rect.width, greaterThan(0));
  expect(rect.height, greaterThan(0));
  expect(rect.left, greaterThanOrEqualTo(-1));
  expect(rect.right, lessThanOrEqualTo(width + 1));
}

Future<void> scrollEntireList(WidgetTester tester) async {
  // The page's own scrollable (search fields hold their own).
  final scrollable = find
      .descendant(
        of: find.byKey(CollectionsScreen.screenKey),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  var guard = 0;
  while (position.pixels < position.maxScrollExtent && guard < 40) {
    position.jumpTo((position.pixels + 280).clamp(0, position.maxScrollExtent));
    await tester.pump();
    expect(tester.takeException(), isNull);
    guard++;
  }
  position.jumpTo(0);
  await tester.pump();
}

Future<void> reveal(WidgetTester tester, Key key) async {
  // The page's own scrollable (search fields hold their own).
  final scrollable = find
      .descendant(
        of: find.byKey(CollectionsScreen.screenKey),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  if (position.hasPixels) {
    position.jumpTo(0);
    await tester.pump();
  }
  await tester.scrollUntilVisible(find.byKey(key), 280, scrollable: scrollable);
  await tester.pump();
}

Future<void> relog(WidgetTester tester, String username) async {
  await tester.tap(find.byKey(HomeShell.logoutKey));
  await settle(tester);
  await tester.tap(find.byKey(const Key('logout-confirm')));
  await settle(tester);
  await signIn(tester, username: username, password: 'demo-only');
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
  await _loadFont(
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBMPlexSansArabic',
  );
  await _loadFont(
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'IBMPlexSansArabic',
  );
  await _loadFont(
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'IBMPlexSansArabic',
  );
  await _loadFont(
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    'IBMPlexSansArabic',
  );
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
  // flutter_tester is bin/cache/artifacts/engine/<arch>/flutter_tester.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final candidate = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  if (candidate.existsSync()) return candidate;
  return null;
}

Future<void> capture(WidgetTester tester, String name) async {
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
    final file = File('/opt/cursor/artifacts/screenshots/$name.png');
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } on FileSystemException {
      // The artifact directory exists for this agent, not in CI.
    }
  });
}
