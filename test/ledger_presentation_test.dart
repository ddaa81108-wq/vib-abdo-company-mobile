import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/presentation.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('P4-001 debt and payment amounts use the status colours', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    for (final path in ['/customers/c_55', '/companies/c_55']) {
      await go(tester, path);
      expectRtl(tester);
      _expectMovementColors(tester, AppStatusColors.light);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await settle(tester);

    for (final path in ['/customers/c_55', '/companies/c_55']) {
      await go(tester, path);
      expect(
        Theme.of(tester.element(find.byKey(const Key('ledger-header'))))
            .brightness,
        Brightness.dark,
      );
      expectRtl(tester);
      _expectMovementColors(tester, AppStatusColors.dark);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('P4-002 the ledger header paints the ageStatus gradient', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(430, 1200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    _expectHeaderGradient(tester, AppStatusColors.light.warningDebt);
    expect(find.text('منذ 4 أيام'), findsWidgets);

    await _toggleDark(tester);
    _expectHeaderGradient(tester, AppStatusColors.dark.warningDebt);
    expectRtl(tester);
  });

  testWidgets('P4-002 overdue uses the overdue gradient', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 1200),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'عميل متأخر',
            'balanceUnits': 10,
            'version': 2,
            'ageStatus': 'overdue',
            'ageStatusLabel': 'متأخر',
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    _expectHeaderGradient(tester, AppStatusColors.light.overdueDebt);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P4-002 a missing ageStatus paints no gradient', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(430, 1200),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'بدون عمر',
            'balanceUnits': 10,
            'version': 2,
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/companies/c_55');
    final ink = tester.widget<Ink>(
      find.descendant(
        of: find.byKey(const Key('ledger-header')),
        matching: find.byType(Ink),
      ),
    );
    expect((ink.decoration! as BoxDecoration).gradient, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ledger layout stays whole across widths, scales, and themes', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    const widths = <double>[320, 360, 393, 430];
    const scales = <double>[1, 1.3, 2];
    for (final dark in [false, true]) {
      if (dark) {
        tester.view.physicalSize = const Size(430, 1400);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await settle(tester);
        await _toggleDark(tester);
      }
      for (final width in widths) {
        for (final scale in scales) {
          tester.view.physicalSize = Size(width, 1400);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await settle(tester);
          expect(
            find.byKey(const Key('screen-ledger-customers')),
            findsOneWidget,
          );
          await _scrollToTop(tester, const Key('screen-ledger-customers'));
          expectRtl(tester);
          expect(find.text(AppStrings.customerLedger), findsOneWidget);
          expect(find.text('posted'), findsNothing);
          await _expectFits(
            tester,
            find.byKey(const Key('ledger-amount-tx_1')),
            const Key('screen-ledger-customers'),
          );
          await _expectFits(
            tester,
            find.byKey(const Key('ledger-amount-tx_2')),
            const Key('screen-ledger-customers'),
          );
          await _expectFits(
            tester,
            find.byKey(const Key('ledger-date-tx_1')),
            const Key('screen-ledger-customers'),
          );
          await _expectFits(
            tester,
            find.byKey(const Key('ledger-header-balance')),
            const Key('screen-ledger-customers'),
          );
          if (scale == 1) _expectAligned(tester);
          await _expectReachable(
            tester,
            const Key('edit-account-card'),
            const Key('screen-ledger-customers'),
          );
          await _expectReachable(
            tester,
            const Key('correct-tx_1'),
            const Key('screen-ledger-customers'),
          );
          await _expectReachable(
            tester,
            const Key('cancel-tx_1'),
            const Key('screen-ledger-customers'),
          );
          expect(tester.takeException(), isNull);
        }
      }
    }

    tester.view.physicalSize = const Size(430, 1400);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await settle(tester);
    await go(tester, '/customers/c_55/edit');
    for (final width in widths) {
      for (final scale in scales) {
        tester.view.physicalSize = Size(width, 1400);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await settle(tester);
        expect(
          find.byKey(const Key('screen-edit-card-customers')),
          findsOneWidget,
        );
        await _scrollToTop(tester, const Key('screen-edit-card-customers'));
        expect(find.text(AppStrings.editCardScope), findsOneWidget);
        expect(find.byKey(const Key('edit-card-name')), findsOneWidget);
        expectRtl(tester);
        await _expectReachable(
          tester,
          const Key('save-account-card'),
          const Key('screen-edit-card-customers'),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('a missing sequence is a dash and dates stay LTR', (
    tester,
  ) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          final raw = Map<String, dynamic>.from(FakeFixtures.ledger());
          final items = [
            for (final item in raw['items'] as List)
              Map<String, dynamic>.from(item as Map),
          ];
          items.first['sequence'] = null;
          raw['items'] = items;
          return LedgerPage.fromData(raw, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/libyan-deposits/c_55');
    expect(find.text(AppStrings.libyanLedger), findsOneWidget);
    expect(_textOf(tester, const Key('ledger-sequence-tx_1')), AppStrings.dash);
    expect(_textOf(tester, const Key('ledger-sequence-tx_2')), '2');
    expect(
      Directionality.of(
        tester.element(
          find.descendant(
            of: find.byKey(const Key('ledger-date-tx_1')),
            matching: find.byType(Text),
          ),
        ),
      ),
      TextDirection.ltr,
    );
    expect(
      Directionality.of(
        tester.element(
          find.descendant(
            of: find.byKey(const Key('ledger-amount-tx_1')),
            matching: find.byType(Text),
          ),
        ),
      ),
      TextDirection.ltr,
    );
  });

  testWidgets('an employee does not see ledger writes', (tester) async {
    await pumpFakeApp(tester, size: const Size(360, 1400));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    _expectWritesHidden(tester);
    expectRtl(tester);
  });

  testWidgets('a limited admin does not see ledger writes', (tester) async {
    await pumpFakeApp(tester, size: const Size(393, 1400));
    await signIn(tester, username: 'limited.admin', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('screen-ledger-customers')), findsOneWidget);
    _expectWritesHidden(tester);
    expectRtl(tester);
  });

  testWidgets('a flag admin cannot open the customer ledger', (tester) async {
    await pumpFakeApp(tester, size: const Size(320, 1400));
    await signIn(tester, username: 'flag.admin', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    expect(find.byKey(const Key('screen-ledger-customers')), findsNothing);
    _expectWritesHidden(tester);
  });

  testWidgets('a guest cannot open the company ledger', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 1400));
    await signIn(tester, username: 'guest.demo', password: 'demo-only');
    await go(tester, '/companies/c_55');
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeDashboard.screenKey), findsNothing);
    expect(find.byKey(const Key('screen-ledger-companies')), findsNothing);
    _expectWritesHidden(tester);
  });

  testWidgets('a system-managed card hides writes', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'كارت نظامي',
            'balanceUnits': 10,
            'version': 3,
            'systemManaged': true,
            'allowedActions': ['edit'],
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/egyptian-deposits/c_55');
    expect(find.text(AppStrings.egyptianLedger), findsOneWidget);
    expect(find.text(AppStrings.systemCard), findsOneWidget);
    _expectWritesHidden(tester);
  });

  testWidgets('a failed card load hides writes', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      overrides: [
        accountCardProvider.overrideWith((ref, key) async {
          return AccountCardDto.fromJson({
            'id': key.$2,
            'name': 'عميل',
            'balanceUnits': '125000',
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.text(AppStrings.retry), findsOneWidget);
    _expectWritesHidden(tester);
  });

  testWidgets('an empty ledger keeps the header actions', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          return LedgerPage.fromData({
            'items': <Object>[],
            'nextBefore': null,
            'hasMore': false,
          }, key.$1);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.text(AppStrings.emptyLedger), findsOneWidget);
    expect(find.byKey(const Key('edit-account-card')), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    expect(find.text(AppStrings.statementHidden), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ledger error retries into the entries', (tester) async {
    final gate = _FailGate();
    await pumpFakeApp(
      tester,
      size: const Size(360, 1400),
      overrides: [
        ledgerProvider.overrideWith((ref, key) async {
          gate.calls++;
          if (gate.failing) throw const NetworkException();
          return ref.read(apiLayerProvider).accounts.ledger(key.$1, key.$2);
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('ledger-loading')), findsNothing);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.byKey(const Key('add-debt')), findsNothing);
    gate.failing = false;
    await tester.tap(find.text(AppStrings.retry));
    await settle(tester);
    expect(find.byKey(const Key('add-debt')), findsOneWidget);
    expect(find.byKey(const Key('load-older')), findsOneWidget);
    expect(find.text(AppStrings.loadOlder), findsOneWidget);
    expect(gate.calls, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline disables ledger writes until the link returns', (
    tester,
  ) async {
    final link = ToggleConnectivity(true);
    await pumpFakeApp(tester, size: const Size(360, 1400), connectivity: link);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    link.setOnline(false);
    await tester.pump();
    await settle(tester);
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text(AppStrings.offline), findsWidgets);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('edit-account-card')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('correct-tx_1')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('add-debt'))).onPressed,
      isNull,
    );
    link.setOnline(true);
    await tester.pump();
    await settle(tester);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('edit-account-card')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ledger and edit card share the 360 dp stack threshold', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    expect(stackLayoutWidth, 360);
    expect(stackLayoutTextScale, 1.3);

    await pumpFakeApp(tester, size: const Size(430, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers/c_55');

    Future<void> size(double width, double scale) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await settle(tester);
      await _scrollToTop(tester, const Key('screen-ledger-customers'));
    }

    await size(360, 1);
    expect(_amountIsStacked(tester), isFalse);
    await _reveal(
      tester,
      find.byKey(const Key('edit-account-card')),
      const Key('screen-ledger-customers'),
    );
    expect(_isStretched(tester, const Key('edit-account-card')), isFalse);

    await size(320, 1);
    expect(_amountIsStacked(tester), isTrue);
    await _reveal(
      tester,
      find.byKey(const Key('edit-account-card')),
      const Key('screen-ledger-customers'),
    );
    expect(_isStretched(tester, const Key('edit-account-card')), isTrue);

    await size(430, 1.3);
    expect(_amountIsStacked(tester), isTrue);
    await _reveal(
      tester,
      find.byKey(const Key('edit-account-card')),
      const Key('screen-ledger-customers'),
    );
    expect(_isStretched(tester, const Key('edit-account-card')), isTrue);

    await go(tester, '/customers/c_55/edit');
    tester.view.physicalSize = const Size(360, 1600);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await settle(tester);
    expect(_isStretched(tester, const Key('save-account-card')), isFalse);

    tester.view.physicalSize = const Size(320, 1600);
    await settle(tester);
    expect(_isStretched(tester, const Key('save-account-card')), isTrue);

    tester.view.physicalSize = const Size(430, 1600);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await settle(tester);
    expect(_isStretched(tester, const Key('save-account-card')), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screenshots of the ledger and edit card', (tester) async {
    final dir = Platform.environment['LEDGER_SCREENSHOT_DIR'];
    if (dir == null || dir.isEmpty) return;

    Future<void> shoot(String name) => saveShot(tester, '$dir/$name.png');

    await pumpFakeApp(tester, size: const Size(360, 780));
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    for (final dark in [false, true]) {
      if (dark) await _toggleDark(tester);
      final theme = dark ? 'dark' : 'light';
      for (final width in [360.0, 430.0]) {
        tester.view.physicalSize = Size(width, 780);
        await settle(tester);
        await go(tester, '/customers/c_55');
        await shoot('customer_ledger_${theme}_${width.toInt()}');
        await go(tester, '/libyan-deposits/c_55');
        await shoot('deposit_ledger_${theme}_${width.toInt()}');
      }
      for (final width in [320.0, 430.0]) {
        tester.view.physicalSize = Size(width, 780);
        await settle(tester);
        await go(tester, '/customers/c_55/edit');
        await shoot('edit_card_${theme}_${width.toInt()}');
      }
    }
  });
}

void _expectMovementColors(WidgetTester tester, AppStatusColors colors) {
  expect(_styleColor(tester, 'tx_1'), colors.debtText);
  expect(_styleColor(tester, 'tx_2'), colors.creditText);
  expect(colors.debtText, isNot(colors.creditText));
}

Color? _styleColor(WidgetTester tester, String id) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(Key('ledger-amount-$id')),
          matching: find.byType(Text),
        ),
      )
      .style
      ?.color;
}

void _expectHeaderGradient(WidgetTester tester, LinearGradient expected) {
  final ink = tester.widget<Ink>(
    find.descendant(
      of: find.byKey(const Key('ledger-header')),
      matching: find.byType(Ink),
    ),
  );
  final gradient =
      (ink.decoration! as BoxDecoration).gradient! as LinearGradient;
  expect(gradient.colors, expected.colors);
  expect(gradient.begin, expected.begin);
  expect(gradient.end, expected.end);
}

String? _textOf(WidgetTester tester, Key key) {
  return tester
      .widget<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .data;
}

void _expectWritesHidden(WidgetTester tester) {
  expect(find.byKey(const Key('edit-account-card')), findsNothing);
  expect(find.byKey(const Key('correct-tx_1')), findsNothing);
  expect(find.byKey(const Key('correct-tx_2')), findsNothing);
  expect(find.byKey(const Key('cancel-tx_1')), findsNothing);
  expect(find.byKey(const Key('add-debt')), findsNothing);
  expect(find.byKey(const Key('add-payment')), findsNothing);
  expect(find.byKey(const Key('full-payment')), findsNothing);
  expect(find.text(AppStrings.correctTransaction), findsNothing);
}

bool _amountIsStacked(WidgetTester tester) {
  final date = tester.getRect(find.byKey(const Key('ledger-date-tx_1')));
  final amount = tester.getRect(find.byKey(const Key('ledger-amount-tx_1')));
  return amount.top >= date.bottom - 1;
}

bool _isStretched(WidgetTester tester, Key key) {
  final width = tester.getSize(find.byKey(key)).width;
  final view = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  return width > view * 0.7;
}

void _expectAligned(WidgetTester tester) {
  final date1 = tester.getRect(find.byKey(const Key('ledger-date-tx_1')));
  final date2 = tester.getRect(find.byKey(const Key('ledger-date-tx_2')));
  final amount1 = tester.getRect(find.byKey(const Key('ledger-amount-tx_1')));
  final amount2 = tester.getRect(find.byKey(const Key('ledger-amount-tx_2')));
  expect((date1.left - date2.left).abs(), lessThan(1.5));
  expect((amount1.right - amount2.right).abs(), lessThan(1.5));
}

Future<void> _scrollToTop(WidgetTester tester, Key screen) async {
  final scrollable = find.descendant(
    of: find.byKey(screen),
    matching: find.byType(Scrollable),
  );
  if (scrollable.evaluate().isEmpty) return;
  tester.state<ScrollableState>(scrollable.first).position.jumpTo(0);
  await tester.pump();
}

Future<void> _reveal(WidgetTester tester, Finder finder, Key screen) async {
  if (finder.evaluate().isNotEmpty) return;
  await _scrollToTop(tester, screen);
  if (finder.evaluate().isNotEmpty) return;
  final scrollable = find
      .descendant(of: find.byKey(screen), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(finder, 240, scrollable: scrollable);
}

Future<void> _expectFits(WidgetTester tester, Finder finder, Key screen) async {
  await _reveal(tester, finder, screen);
  final text = tester.widget<Text>(
    find.descendant(of: finder, matching: find.byType(Text)).first,
  );
  expect(text.overflow, isNot(TextOverflow.ellipsis));
  expect(text.overflow, isNot(TextOverflow.fade));
  expect(text.maxLines, isNull);
  final box = tester.renderObject<RenderBox>(
    find.descendant(of: finder, matching: find.byType(Text)).first,
  );
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: Directionality.of(tester.element(finder)),
    textScaler: MediaQuery.textScalerOf(tester.element(finder)),
  )..layout(maxWidth: box.size.width);
  expect(painter.width, lessThanOrEqualTo(box.size.width + 1));
  expect(painter.height, lessThanOrEqualTo(box.size.height + 1));
  painter.dispose();
  expect(box.size.width, greaterThan(0));
}

Future<void> _toggleDark(WidgetTester tester) async {
  final width = tester.view.physicalSize.width;
  if (width <= 560) {
    await tester.tap(find.byKey(HomeShell.menuKey));
    await settle(tester);
    await tester.tap(find.text(AppStrings.themeDark));
    await settle(tester);
    if (find.byType(Drawer).evaluate().isNotEmpty) {
      Navigator.of(tester.element(find.byType(Drawer))).pop();
      await settle(tester);
    }
    return;
  }
  await tester.tap(find.byTooltip(AppStrings.themeDark));
  await settle(tester);
}

Future<void> _expectReachable(WidgetTester tester, Key key, Key screen) async {
  final finder = find.byKey(key);
  await _reveal(tester, finder, screen);
  expect(finder, findsOneWidget);
  final size = tester.getSize(finder);
  expect(size.width, greaterThan(8));
  expect(size.height, greaterThanOrEqualTo(48));
  final hit = tester.hitTestOnBinding(tester.getCenter(finder));
  expect(hit.path, isNotEmpty);
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

/// Loads Cairo, JetBrains Mono, and Material Icons after the test app is up.
/// Call from [WidgetTester.runAsync]. flutter_tester does not bundle those
/// faces, so icons and Arabic otherwise paint as empty squares.
Future<void> loadScreenshotFonts() async {
  await _loadFont('assets/fonts/Cairo-Variable.ttf', 'Cairo');
  await _loadFont('assets/fonts/JetBrainsMono-Bold.ttf', 'JetBrainsMono');
  await _loadFont('assets/fonts/JetBrainsMono-ExtraBold.ttf', 'JetBrainsMono');
  final icons = _materialIconsFile();
  if (icons == null) {
    throw StateError('MaterialIcons-Regular.otf was not found');
  }
  await ui.loadFontFromList(
    await icons.readAsBytes(),
    fontFamily: 'MaterialIcons',
  );
}

Future<void> _loadFont(String path, String family) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('missing font $path');
  }
  await ui.loadFontFromList(await file.readAsBytes(), fontFamily: family);
}

File? _materialIconsFile() {
  final fromTester = File(Platform.resolvedExecutable).parent.parent.parent;
  final candidates = [
    File('${fromTester.path}/material_fonts/MaterialIcons-Regular.otf'),
    File(
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate;
  }
  return null;
}

Future<void> saveShot(WidgetTester tester, String path) async {
  await settle(tester);
  await tester.pump();
  final boundary = _viewBoundary(tester);
  final image = await boundary.toImage();
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  });
}

RenderRepaintBoundary _viewBoundary(WidgetTester tester) {
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  RenderRepaintBoundary? match;
  RenderRepaintBoundary? largest;
  var area = 0.0;
  for (final object in tester.allRenderObjects) {
    if (object is! RenderRepaintBoundary ||
        !object.hasSize ||
        object.size.width <= 0 ||
        object.size.height <= 0) {
      continue;
    }
    final next = object.size.width * object.size.height;
    if (next > area) {
      largest = object;
      area = next;
    }
    final close =
        (object.size.width - view.width).abs() < 2 &&
        (object.size.height - view.height).abs() < 2;
    if (close) match = object;
  }
  return match ?? largest!;
}

class _FailGate {
  var failing = true;
  var calls = 0;
}
