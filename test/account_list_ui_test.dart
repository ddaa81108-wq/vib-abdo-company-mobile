import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/accounts/account_list_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/presentation.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  test('sinceDays stays «منذ N أيام» for ledger and home callers', () {
    expect(sinceDays(null), AppStrings.dash);
    expect(sinceDays(1), 'منذ 1 أيام');
    expect(sinceDays(2), 'منذ 2 أيام');
    expect(sinceDays(4), 'منذ 4 أيام');
    expect(sinceDays(11), 'منذ 11 أيام');
  });

  test('a server age label wins; the list count is only a fallback', () {
    expect(
      singleAgeText(
        serverLabel: 'منذ 4 أيام',
        ageStatus: 'warning',
        debtAgeDays: 4,
      ),
      'منذ 4 أيام',
    );
    expect(
      singleAgeText(serverLabel: 'تسمية الخادم', debtAgeDays: 2),
      'تسمية الخادم',
    );
    expect(
      singleAgeText(ageStatus: 'warning', debtAgeDays: 4),
      AppStrings.warningAge,
    );
    expect(singleAgeText(debtAgeDays: 1), 'منذ يوم');
    expect(singleAgeText(debtAgeDays: 2), 'منذ يومين');
    expect(singleAgeText(debtAgeDays: 4), 'منذ 4 أيام');
    expect(singleAgeText(debtAgeDays: 10), 'منذ 10 أيام');
    expect(singleAgeText(debtAgeDays: 11), 'منذ 11 يومًا');
    expect(singleAgeText(debtAgeDays: 0), 'منذ 0 يومًا');
    expect(singleAgeText(debtAgeDays: -3), 'منذ -3 يومًا');
    expect(singleAgeText(), isNull);
  });

  test('card columns follow width and text scale', () {
    expect(accountListColumns(320), 1);
    expect(accountListColumns(360), 1);
    expect(accountListColumns(393), 2);
    expect(accountListColumns(430), 2);
    expect(accountListColumns(393, textScale: 1.3), 1);
    expect(accountListColumns(430, textScale: 1.3), 1);
    expect(accountListColumns(430, textScale: 2), 1);
  });

  testWidgets('customer and company cards show the server age once', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    // The fake client delays on a timer. Read the DTOs on the real clock so
    // the expectation follows the payload (#17 included) without hanging.
    final loaded = await tester.runAsync(() async {
      final customers = await layer.accounts.list(AccountSection.customers);
      final companies = await layer.accounts.list(AccountSection.companies);
      final home = await layer.home.fetch();
      return (
        customer: customers.page.items.firstWhere((card) => card.id == 'c_55'),
        company: companies.page.items.firstWhere((card) => card.id == 'c_55'),
        ticker: home.oldDebts!.firstWhere(
          (debt) =>
              debt.id == 'c_55' &&
              debt.section == AccountSection.customers.sectionKey.key,
        ),
      );
    });
    final customerCard = loaded!.customer;
    final companyCard = loaded.company;
    final tickerDebt = loaded.ticker;
    // #17: the card label names debtAgeDays, and the home bulletin copies it.
    expect(customerCard.ageStatusLabel, 'منذ ${customerCard.debtAgeDays} أيام');
    expect(companyCard.ageStatusLabel, 'منذ ${companyCard.debtAgeDays} أيام');
    expect(tickerDebt.ageStatusLabel, customerCard.ageStatusLabel);
    expect(tickerDebt.debtAgeDays, customerCard.debtAgeDays);

    await go(tester, '/customers');
    expectRtl(tester);
    _expectSingleAge(tester, customerCard, AccountSection.customers);
    expect(
      tester.widget<Text>(find.byKey(const Key('ticker-age-c_55'))).data,
      singleAgeText(
        serverLabel: tickerDebt.ageStatusLabel,
        ageStatus: tickerDebt.ageStatus,
        debtAgeDays: tickerDebt.debtAgeDays,
      ),
    );

    await go(tester, '/companies');
    _expectSingleAge(tester, companyCard, AccountSection.companies);
  });

  testWidgets('amounts sit on the RTL start edge in light and dark', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    for (final dark in [false, true]) {
      if (dark) {
        await _setDark(tester);
      }
      await go(tester, '/customers');
      expectRtl(tester);
      final theme = Theme.of(tester.element(find.byType(HomeShell)));
      expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
      _expectAmountOnStart(tester, '320 د.ل');
      final gradient = _cardGradient(tester);
      expect(
        gradient.colors.first,
        dark ? const Color(0xFF78551E) : const Color(0xFFFF9A00),
      );
    }
  });

  testWidgets('each role only sees the account actions it may use', (
    tester,
  ) async {
    final layer = await pumpFakeApp(tester, size: const Size(800, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final customers = await tester.runAsync(
      () => layer.accounts.list(AccountSection.customers),
    );
    final zeroCard = customers!.page.items.firstWhere(
      (card) => card.balanceUnits == 0 && !card.systemManaged,
    );
    final zeroKey = ValueKey('zero-review-${zeroCard.id}');
    await _expectActions(
      tester,
      path: '/customers',
      add: true,
      assign: true,
      pin: true,
      // #25 shows this only for a 0 balance with a pending review. The
      // fixed fixture's 0-balance card has no pending review, so it stays hidden.
      zero: false,
      zeroKey: zeroKey,
      rate: false,
    );
    await _expectActions(
      tester,
      path: '/companies',
      add: true,
      assign: true,
      pin: true,
      zero: false,
      rate: false,
    );
    await _expectActions(
      tester,
      path: '/libyan-deposits',
      add: true,
      assign: false,
      pin: true,
      zero: false,
      rate: false,
    );
    await _expectActions(
      tester,
      path: '/egyptian-deposits',
      add: true,
      assign: false,
      pin: true,
      zero: false,
      rate: true,
    );

    await _switchUser(tester, 'employee.demo');
    await _expectActions(
      tester,
      path: '/customers',
      add: false,
      assign: false,
      pin: false,
      zero: false,
      rate: false,
    );
    expect(find.byKey(const Key('account-search')), findsOneWidget);
    for (final path in [
      '/companies',
      '/libyan-deposits',
      '/egyptian-deposits',
    ]) {
      await go(tester, path);
      expect(find.byKey(Key('screen-${path.substring(1)}')), findsNothing);
      expect(find.byKey(const Key('add-account')), findsNothing);
      expect(find.byKey(const Key('save-rate')), findsNothing);
    }

    await _switchUser(tester, 'limited.admin');
    await _expectActions(
      tester,
      path: '/customers',
      add: false,
      assign: false,
      pin: false,
      zero: false,
      rate: false,
    );
    await go(tester, '/companies');
    expect(find.byKey(const Key('screen-companies')), findsNothing);

    for (final user in ['flag.admin', 'guest.demo']) {
      await _switchUser(tester, user);
      await go(tester, '/customers');
      expect(find.byKey(const Key('screen-customers')), findsNothing);
      expect(find.byKey(const Key('add-account')), findsNothing);
      expect(find.byKey(const Key('zero-review')), findsNothing);
      expect(find.byKey(const Key('pin-c_55')), findsNothing);
      expect(find.byKey(const Key('assign-mode')), findsNothing);
    }
  });

  testWidgets('offline keeps permitted writes visible and disabled', (
    tester,
  ) async {
    final link = ToggleConnectivity(true);
    await pumpFakeApp(tester, size: const Size(800, 2200), connectivity: link);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');
    link.setOnline(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('add-account')))
          .onPressed,
      isNull,
    );
    final pin = find.byKey(const Key('pin-c_55'));
    await tester.ensureVisible(pin);
    expect(tester.widget<IconButton>(pin).onPressed, isNull);
    expect(find.byKey(const Key('zero-review')), findsNothing);
  });

  testWidgets('lists lay out at phone widths and large text', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    const widths = [320.0, 360.0, 393.0, 430.0];
    const scales = [1.0, 1.3, 2.0];
    const paths = [
      '/customers',
      '/companies',
      '/libyan-deposits',
      '/egyptian-deposits',
    ];
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in widths) {
      for (final scale in scales) {
        tester.view.physicalSize = Size(width, 2400);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final path in paths) {
          await go(tester, path);
          expect(
            find.byKey(Key('screen-${path.substring(1)}')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          final list = find
              .descendant(
                of: find.byKey(Key('screen-${path.substring(1)}')),
                matching: find.byType(Scrollable),
              )
              .first;
          await _reveal(tester, find.byKey(const Key('account-search')), list);
          await _reveal(tester, find.byKey(const Key('add-account')), list);
          await _reveal(
            tester,
            find.byKey(const Key('account-card-c_55')),
            list,
          );
          await _reveal(tester, find.byKey(const Key('pin-c_55')), list);
          if (path == '/customers') {
            await _reveal(tester, find.byKey(const Key('assign-mode')), list);
          }
          if (path == '/egyptian-deposits') {
            await _reveal(
              tester,
              find.byKey(const Key('exchange-rate-card')),
              list,
            );
            await _reveal(tester, find.byKey(const Key('save-rate')), list);
          }
          expect(tester.takeException(), isNull);
        }
      }
    }

    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await go(tester, '/customers');
    final customers = find
        .descendant(
          of: find.byKey(const Key('screen-customers')),
          matching: find.byType(Scrollable),
        )
        .first;
    await _reveal(tester, find.byKey(const Key('add-account')), customers);
    await tester.tap(find.byKey(const Key('add-account')));
    await settle(tester);
    expect(find.byKey(const Key('create-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('create-name')),
      'اسم تجريبي طويل بما يكفي ليلتف على شاشة ضيقة',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byKey(const Key('create-name')))).pop();
    await settle(tester);

    await _reveal(tester, find.byKey(const Key('assign-mode')), customers);
    await tester.tap(find.byKey(const Key('assign-mode')));
    await settle(tester);
    expect(find.byKey(const Key('assignee-field')), findsOneWidget);
    expect(find.text('موظف استلام تجريبي'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account lists screenshot light and dark at 320 and 430', (
    tester,
  ) async {
    const dirPath = '/opt/cursor/artifacts';
    try {
      Directory(dirPath).createSync(recursive: true);
    } on FileSystemException {
      return;
    }
    await pumpFakeApp(tester, size: const Size(320, 1200));
    await tester.runAsync(_loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    const screens = {
      '/customers': 'customers',
      '/companies': 'companies',
      '/libyan-deposits': 'libyan_deposits',
      '/egyptian-deposits': 'egyptian_deposits',
    };
    for (final dark in [false, true]) {
      if (dark) await _setDark(tester);
      for (final width in [320.0, 430.0]) {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        for (final screen in screens.entries) {
          await go(tester, screen.key);
          await tester.pump();
          final name =
              '${screen.value}_${dark ? 'dark' : 'light'}_${width.toInt()}';
          await _capture(tester, '$dirPath/$name.png');
        }
      }
    }
  });
}

void _expectSingleAge(
  WidgetTester tester,
  AccountCardDto card,
  AccountSection section,
) {
  final shown = singleAgeText(
    serverLabel: card.ageStatusLabel,
    ageStatus: card.ageStatus,
    section: section,
    debtAgeDays: card.debtAgeDays,
  );
  final finder = find.byKey(Key('account-card-${card.id}'));
  final age = tester.widget<Text>(find.byKey(Key('account-age-${card.id}')));
  expect(age.data, shown);
  expect(shown, card.ageStatusLabel);
  expect(
    find.descendant(
      of: finder,
      matching: find.byKey(Key('account-age-${card.id}')),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(of: finder, matching: find.text(shown!)),
    findsOneWidget,
  );
  final days = card.debtAgeDays;
  if (days == null) return;
  final count = ageCountPhrase(days);
  if (count == shown) return;
  expect(find.descendant(of: finder, matching: find.text(count)), findsNothing);
}

void _expectAmountOnStart(WidgetTester tester, String amount) {
  final card = tester.getRect(find.byKey(const Key('account-card-c_55')));
  final box = tester.getRect(
    find.descendant(
      of: find.byKey(const Key('account-card-c_55')),
      matching: find.text(amount),
    ),
  );
  expect(card.right - box.right, lessThan(box.left - card.left));
}

LinearGradient _cardGradient(WidgetTester tester) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byKey(const Key('account-card-c_55')),
      matching: find.byType(Ink),
    ),
  );
  return (ink.decoration! as BoxDecoration).gradient! as LinearGradient;
}

Future<void> _expectActions(
  WidgetTester tester, {
  required String path,
  required bool add,
  required bool assign,
  required bool pin,
  required bool zero,
  required bool rate,
  Key zeroKey = const Key('zero-review'),
}) async {
  await go(tester, path);
  expect(find.byKey(Key('screen-${path.substring(1)}')), findsOneWidget);
  expectRtl(tester);
  expect(
    find.byKey(const Key('add-account')),
    add ? findsOneWidget : findsNothing,
  );
  expect(
    find.byKey(const Key('assign-mode')),
    assign ? findsOneWidget : findsNothing,
  );
  expect(
    find.byKey(const Key('pin-c_55')),
    pin ? findsOneWidget : findsNothing,
  );
  expect(find.byKey(const Key('zero-review')), findsNothing);
  expect(find.byKey(zeroKey), zero ? findsOneWidget : findsNothing);
  expect(
    find.byKey(const Key('save-rate')),
    rate ? findsOneWidget : findsNothing,
  );
  expect(
    find.byKey(const Key('rate-field')),
    rate ? findsOneWidget : findsNothing,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _switchUser(WidgetTester tester, String username) async {
  await tester.tap(find.byKey(HomeShell.logoutKey));
  await settle(tester);
  await signIn(tester, username: username, password: 'demo-only');
}

Future<void> _setDark(WidgetTester tester) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (width <= 560) {
    await tester.tap(find.byKey(HomeShell.menuKey));
    await settle(tester);
    await tester.tap(find.text(AppStrings.themeDark));
    await settle(tester);
    if (find.byType(Drawer).evaluate().isNotEmpty) {
      Navigator.of(tester.element(find.byType(Drawer))).pop();
      await settle(tester);
    }
  } else {
    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await settle(tester);
  }
  expect(
    Theme.of(tester.element(find.byType(HomeShell))).brightness,
    Brightness.dark,
  );
}

Future<void> _reveal(WidgetTester tester, Finder target, Finder list) async {
  if (target.evaluate().isNotEmpty) {
    final top = tester.getTopLeft(target).dy;
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    if (top >= 0 && top < height) return;
    await tester.scrollUntilVisible(
      target,
      top < 0 ? -400 : 400,
      scrollable: list,
    );
    return;
  }
  try {
    await tester.scrollUntilVisible(target, 500, scrollable: list);
  } on StateError {
    await tester.scrollUntilVisible(target, -500, scrollable: list);
  }
}

Future<void> _loadScreenshotFonts() async {
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
  // flutter_tester lives in bin/cache/artifacts/engine/<arch>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final candidate = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  if (candidate.existsSync()) return candidate;
  return null;
}

Future<void> _capture(WidgetTester tester, String path) async {
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
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  try {
    File(path).writeAsBytesSync(bytes!);
  } on FileSystemException {
    return;
  }
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
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
