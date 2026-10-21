import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/collections/collections_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('each fake role only sees the collections actions it may use', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(390, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');

    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    expect(find.text(AppStrings.employeeTotals), findsOneWidget);
    expect(find.text(AppStrings.payroll), findsOneWidget);
    expect(find.text(AppStrings.myPayroll), findsNothing);
    await expectPresent(tester, const [
      Key('submit-as_1'),
      Key('unlinked-collection'),
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('cash-sb_2'),
      Key('close-batch'),
      Key('unlinked-approve-ur_1'),
      Key('unlinked-link-ur_1'),
      Key('unlinked-reject-ur_1'),
      Key('unlinked-cash-ur_2'),
    ]);
    expect(find.byKey(const Key('unlinked-cash-ur_1')), findsNothing);
    expect(find.byKey(const Key('unlinked-reject-ur_2')), findsNothing);

    await relog(tester, 'limited.admin.demo');
    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    expect(find.text(AppStrings.myPayroll), findsOneWidget);
    expect(find.text(AppStrings.payroll), findsNothing);
    await expectPresent(tester, const [
      Key('submit-as_1'),
      Key('unlinked-collection'),
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('unlinked-approve-ur_1'),
      Key('unlinked-link-ur_1'),
      Key('unlinked-reject-ur_1'),
    ]);
    expect(find.byKey(const Key('cash-sb_2')), findsNothing);
    expect(find.byKey(const Key('close-batch')), findsNothing);
    expect(find.byKey(const Key('unlinked-cash-ur_2')), findsNothing);
    expect(find.byKey(const Key('unlinked-cash-ur_1')), findsNothing);

    await relog(tester, 'employee.demo');
    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-metrics')), findsNothing);
    expect(find.text(AppStrings.employeeTotals), findsNothing);
    expect(find.text(AppStrings.myPayroll), findsOneWidget);
    expect(find.text(AppStrings.payroll), findsNothing);
    await expectPresent(tester, const [
      Key('submit-as_1'),
      Key('unlinked-collection'),
    ]);
    for (final key in const [
      Key('approve-sb_1'),
      Key('reject-sb_1'),
      Key('cash-sb_2'),
      Key('close-batch'),
      Key('unlinked-approve-ur_1'),
      Key('unlinked-link-ur_1'),
      Key('unlinked-reject-ur_1'),
      Key('unlinked-cash-ur_2'),
    ]) {
      expect(find.byKey(key), findsNothing);
    }

    await relog(tester, 'flag.admin.demo');
    await go(tester, '/collections');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(CollectionsScreen.screenKey), findsNothing);
    expect(find.byKey(const Key('submit-as_1')), findsNothing);

    await relog(tester, 'guest.demo');
    await go(tester, '/collections');
    expect(find.byKey(HomeDashboard.screenKey), findsOneWidget);
    expect(find.byKey(CollectionsScreen.screenKey), findsNothing);
    expect(find.byKey(const Key('unlinked-collection')), findsNothing);
  });

  testWidgets('light and dark keep status colours, RTL, and amount direction', (
    tester,
  ) async {
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
  });

  testWidgets(
    'receipt cards do not overflow across phone widths and text scales',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(430, 900));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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
          await expectFits(tester, const Key('submit-as_1'), width);
          await expectFits(tester, const Key('approve-sb_1'), width);
          await expectFits(tester, const Key('reject-sb_1'), width);
          await expectFits(tester, const Key('cash-sb_2'), width);
          await expectFits(tester, const Key('close-batch'), width);
          await expectFits(tester, const Key('unlinked-reject-ur_1'), width);
          await expectFits(tester, const Key('unlinked-cash-ur_2'), width);
          await expectFits(tester, const Key('unlinked-collection'), width);
          await reveal(tester, const Key('assignment-as_1'));
          expectAmountInside(tester, const Key('assignment-as_1'), '320 د.ل');
          await reveal(tester, const Key('submission-sb_2'));
          expectAmountInside(tester, const Key('submission-sb_2'), '250 د.ل');
          await reveal(tester, const Key('unlinked-card-ur_1'));
          expectAmountInside(tester, const Key('unlinked-card-ur_1'), '50 د.ل');
        }
      }
    },
  );

  testWidgets(
    'the unlinked and assignment forms stay inside a narrow large-text sheet',
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
      expect(find.byKey(const Key('assignment-full')), findsOneWidget);
      expect(find.text(AppStrings.modeFull), findsWidgets);
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
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-loading')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);

    gate.complete(_emptyOverview);
    await settle(tester);
    expect(find.byKey(const Key('collections-loading')), findsNothing);
    expect(find.byKey(const Key('collections-empty-receipts')), findsOneWidget);
    expect(
      find.byKey(const Key('collections-empty-assignments')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('collections-empty-totals')), findsOneWidget);
    expect(find.text(AppStrings.emptyCollections), findsOneWidget);
    expect(find.text(AppStrings.emptyAssignments), findsOneWidget);
    expect(find.byKey(const Key('payroll-retry')), findsOneWidget);
    expect(find.byKey(const Key('close-batch')), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);

    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text(AppStrings.offline), findsWidgets);
    final unlinked = tester.widget<FilledButton>(
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
          .widget<FilledButton>(find.byKey(const Key('unlinked-collection')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('approved unlinked receipts keep the locked status colour', (
    tester,
  ) async {
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
                amountUnits: 15,
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
    final card = tester.widget<Card>(
      find.byKey(const Key('unlinked-card-ur_ok')),
    );
    expect(card.color, AppStatusColors.light.unlinkedApproved);
    expect(card.color, const Color(0xFF178447));
    expect(find.text('15 د.ل'), findsOneWidget);
    expect(find.text(AppStrings.approved), findsOneWidget);
    expect(find.byKey(const Key('unlinked-approve-ur_ok')), findsNothing);
    expect(find.byKey(const Key('unlinked-reject-ur_ok')), findsNothing);
  });

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
  await reveal(tester, const Key('awaiting-cash-sb_2'));
  await reveal(tester, const Key('unlinked-card-ur_1'));
  await reveal(tester, const Key('unlinked-card-ur_2'));
  await reveal(tester, const Key('submission-sb_2'));
  final colors = Theme.of(screen).extension<AppStatusColors>()!;
  final pending = tester.widget<Card>(
    find.byKey(const Key('unlinked-card-ur_1')),
  );
  final rejected = tester.widget<Card>(
    find.byKey(const Key('unlinked-card-ur_2')),
  );
  expect(pending.color, colors.unlinkedPending);
  expect(rejected.color, colors.unlinkedPending);
  expect(pending.color, const Color(0xFF4F5F73));
  final label = find.byKey(const Key('awaiting-cash-sb_2'));
  final text = tester.widget<Text>(label);
  expect(text.data, AppStrings.awaitingCash);
  expect(
    text.style?.color,
    Theme.of(tester.element(label)).colorScheme.onSurfaceVariant,
  );
  expect(text.style?.color, isNot(colors.unlinkedPending));
  expectAmountInside(tester, const Key('submission-sb_2'), '250 د.ل');
  await expectFits(tester, const Key('cash-sb_2'), width);
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
  final scrollable = find.descendant(
    of: find.byKey(CollectionsScreen.screenKey),
    matching: find.byType(Scrollable),
  );
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
  final scrollable = find.descendant(
    of: find.byKey(CollectionsScreen.screenKey),
    matching: find.byType(Scrollable),
  );
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
