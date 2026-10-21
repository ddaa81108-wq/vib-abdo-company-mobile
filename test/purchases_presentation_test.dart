import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/purchases/purchases_screen.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('purchases renders RTL in light and dark', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expectRtl(tester);
    expect(themeOf(tester).brightness, Brightness.light);
    expect(find.text(AppStrings.alBayan), findsOneWidget);
    expect(find.text(AppStrings.simsim), findsOneWidget);
    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(find.byKey(const Key('purchase-entry-pe_1')), findsOneWidget);
    expect(find.text('فودافون كاش'), findsOneWidget);
    expect(cardColor(tester), AppStatusColors.light.dayTones[2]);

    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await settle(tester);
    expect(themeOf(tester).brightness, Brightness.dark);
    expectRtl(tester);
    expect(cardColor(tester), AppStatusColors.dark.dayTones[2]);
    expect(
      themeOf(tester).scaffoldBackgroundColor,
      buildAppTheme(Brightness.dark).scaffoldBackgroundColor,
    );
  });

  for (final width in const <double>[320, 360, 393, 430]) {
    for (final scale in const <double>[1, 1.3, 2]) {
      testWidgets('purchases fits ${width.toInt()} dp at text scale $scale', (
        tester,
      ) async {
        await pumpScaled(tester, Size(width, 900), scale);
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await go(tester, '/purchases');

        expect(textScaleOf(tester), scale);
        expectRtl(tester);
        expect(find.byKey(const Key('purchase-books')), findsOneWidget);
        expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
        expect(find.byKey(const Key('purchase-entry-pe_1')), findsOneWidget);
        expect(find.byKey(const Key('purchases-lifetime')), findsOneWidget);
        expect(find.byKey(const Key('add-purchase')), findsOneWidget);
        expect(find.byKey(const Key('finalize-day')), findsOneWidget);
        expect(find.byKey(const Key('edit-pe_1')), findsOneWidget);
        expect(find.byKey(const Key('delete-pe_1')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('سمسم selects the other ledger', (tester) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    await tester.tap(find.text(AppStrings.simsim));
    await settle(tester);
    final books = tester.widget<SegmentedButton<PurchaseBook>>(
      find.byKey(const Key('purchase-books')),
    );
    expect(books.selected, {PurchaseBook.simsim});
    expectRtl(tester);
    expect(find.byKey(PurchasesScreen.screenKey), findsOneWidget);
  });

  testWidgets('an empty ledger shows the empty pane and server totals', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          return PurchasesBookPage.fromData({
            'days': <Map<String, dynamic>>[],
            'lifetimeTotals': {
              'resultUnits': 10,
              'paidUnits': 4,
              'remainingUnits': 6,
            },
          });
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchases-empty')), findsOneWidget);
    expect(find.text(AppStrings.emptyPurchases), findsOneWidget);
    expect(find.byKey(const Key('add-purchase')), findsNothing);
    expect(find.byKey(const Key('finalize-day')), findsNothing);
    final lifetime = find.byKey(const Key('purchases-lifetime'));
    expect(
      find.descendant(of: lifetime, matching: find.textContaining('10')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading hides actions until the server page arrives', (
    tester,
  ) async {
    final pending = Completer<PurchasesBookPage>();
    await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      overrides: [purchasesProvider.overrideWith((ref) => pending.future)],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.byKey(const Key('purchases-loading')), findsOneWidget);
    expect(find.byKey(const Key('add-purchase')), findsNothing);
    expect(find.byKey(const Key('purchases-empty')), findsNothing);

    pending.complete(
      PurchasesBookPage.fromData({
        'days': <Map<String, dynamic>>[],
        'lifetimeTotals': {
          'resultUnits': 1,
          'paidUnits': 1,
          'remainingUnits': 0,
        },
      }),
    );
    await settle(tester);
    expect(find.byKey(const Key('purchases-loading')), findsNothing);
    expect(find.byKey(const Key('purchases-empty')), findsOneWidget);
  });

  testWidgets('an error hides writes until retry', (tester) async {
    var failing = true;
    await pumpFakeApp(
      tester,
      size: const Size(360, 800),
      overrides: [
        purchasesProvider.overrideWith((ref) async {
          if (failing) throw const NetworkException();
          return ref
              .read(apiLayerProvider)
              .purchases
              .list(PurchaseBook.alBayan);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.byKey(const Key('add-purchase')), findsNothing);
    expect(find.byKey(const Key('finalize-day')), findsNothing);

    failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('add-purchase')), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });

  testWidgets('offline keeps purchase actions visible and disabled', (
    tester,
  ) async {
    final link = ToggleConnectivity(true);
    await pumpFakeApp(tester, size: const Size(360, 900), connectivity: link);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    expect(pressed(tester, const Key('add-purchase')), isNotNull);
    expect(pressed(tester, const Key('finalize-day')), isNotNull);

    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.byKey(const Key('add-purchase')), findsOneWidget);
    expect(find.byKey(const Key('finalize-day')), findsOneWidget);
    expect(pressed(tester, const Key('add-purchase')), isNull);
    expect(pressed(tester, const Key('finalize-day')), isNull);
    expect(pressed(tester, const Key('edit-pe_1')), isNull);
    expect(pressed(tester, const Key('delete-pe_1')), isNull);
  });

  testWidgets('a reader sees the ledger and no write actions', (tester) async {
    final layer = await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    layer.permissions.applyFromServer(
      const ['purchases.read'],
      role: 'employee',
      sectionAccess: const {'purchases': 'read'},
    );
    await tester.pump();

    expect(find.byKey(PurchasesScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('purchase-day-12')), findsOneWidget);
    expect(find.byKey(const Key('add-purchase')), findsNothing);
    expect(find.byKey(const Key('finalize-day')), findsNothing);
    expect(find.byKey(const Key('edit-pe_1')), findsNothing);
    expect(find.byKey(const Key('delete-pe_1')), findsNothing);
  });

  testWidgets('screenshots of purchases in light and dark at 360 and 430', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 844));
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await capturePurchases(tester, 'purchases-light-360');

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    await settle(tester);
    await capturePurchases(tester, 'purchases-light-430');

    await go(tester, '/account');
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await go(tester, '/purchases');
    await capturePurchases(tester, 'purchases-dark-430');

    tester.view.physicalSize = const Size(360, 844);
    await settle(tester);
    await capturePurchases(tester, 'purchases-dark-360');
  });
}

Future<void> pumpScaled(WidgetTester tester, Size size, double scale) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpFakeApp(tester, size: size);
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

Color? cardColor(WidgetTester tester) {
  return tester.widget<Card>(find.byKey(const Key('purchase-day-12'))).color;
}

VoidCallback? pressed(WidgetTester tester, Key key) {
  final button = tester.widget<ButtonStyleButton>(find.byKey(key));
  return button.onPressed;
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
    final file = File('/opt/cursor/artifacts/purchases-presentation/$name.png');
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } on FileSystemException {
      // The artifact directory exists for this agent, not in CI.
    }
  });
}
