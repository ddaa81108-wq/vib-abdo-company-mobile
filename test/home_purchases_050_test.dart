import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_dashboard.dart';
import 'package:vib_abdo_company_mobile/features/home/home_design_options.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  for (final size in const [Size(360, 800), Size(360, 640)]) {
    testWidgets('admin home fits and centers tiles at ${size.height}', (
      tester,
    ) async {
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      _expectGridFits(tester, settings: true);
      _expectCentered(tester, HomeShell.sectionKey(SectionKey.customers));
      _expectCentered(tester, HomeShell.sectionKey(SectionKey.collections));
      _expectCentered(tester, HomeDashboard.settingsTileKey);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('employee home fits and centers its tiles', (tester) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(find.text('استلامات الديون'), findsOneWidget);
    expect(find.text(AppStrings.settings), findsNothing);
    _expectGridFits(tester, settings: false);
    _expectCentered(tester, HomeShell.sectionKey(SectionKey.collections));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the purchase separator is the carry line and the new date', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    final rollover = find.byKey(const Key('purchase-rollover-11'));
    await tester.scrollUntilVisible(
      rollover,
      120,
      scrollable: _verticalScrollable,
    );
    expect(rollover, findsOneWidget);
    expect(
      find.descendant(
        of: rollover,
        matching: find.text('الباقي المرحّل من اليوم السابق'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rollover,
        matching: find.text('الباقي المُرحّل لليوم التالي — يوم #11'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rollover, matching: find.text('2026-10-19')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rollover, matching: find.text('2026-10-18')),
      findsNothing,
    );
    expect(
      find.descendant(of: rollover, matching: find.textContaining('يوم #11')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rollover,
        matching: find.text(AppStrings.openDayCorrection),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final gap = tester.getRect(rollover);
    final today = tester.getRect(find.byKey(const Key('purchase-entry-pe_1')));
    expect(gap.bottom, lessThanOrEqualTo(today.top + 1));
    expect(gap.height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchases open on the last day with totals underneath', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');

    expect(find.text('إجماليات السجل من البداية'), findsNothing);
    expect(find.byKey(const Key('purchases-lifetime')), findsNothing);

    final header = tester.getRect(find.byKey(const Key('purchase-ledger')));
    final latest = tester.getRect(
      find.byKey(const ValueKey('purchase-inline-new')),
    );
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(header.top, lessThan(200));
    expect(latest.bottom, lessThanOrEqualTo(view.height + 1));
    expect(latest.top, greaterThan(header.bottom));

    final totals = tester.getRect(find.byKey(const Key('purchase-day-12')));
    expect(totals.top, greaterThanOrEqualTo(latest.bottom - 1));

    final openLabel = tester.getRect(
      find.text('الباقي المرحّل من اليوم السابق'),
    );
    final closeLabel = tester.getRect(
      find.text('الباقي المُرحّل لليوم التالي — يوم #11'),
    );
    for (final rect in [openLabel, closeLabel]) {
      expect(rect.left, greaterThanOrEqualTo(-1));
      expect(rect.right, lessThanOrEqualTo(view.width + 1));
    }
    expect(find.byKey(const Key('purchase-carry-open-11')), findsOneWidget);
    expect(find.byKey(const Key('purchase-carry-close-11')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in const [360.0, 1024.0, 1280.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
        'carry pills stay one line at ${width.toInt()} scale $scale',
        (tester) async {
          await pumpFakeApp(tester, size: Size(width, 800), textScale: scale);
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/purchases');
          await tester.scrollUntilVisible(
            find.byKey(const Key('purchase-rollover-11')),
            80,
            scrollable: _verticalScrollable,
          );
          for (final key in const [
            Key('purchase-carry-open-11'),
            Key('purchase-carry-close-11'),
          ]) {
            _expectSingleLineAmount(tester, key);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('the separator row lines up with the ledger columns', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1280, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    final rollover = find.byKey(const Key('purchase-rollover-11'));
    await tester.scrollUntilVisible(
      rollover,
      80,
      scrollable: _verticalScrollable,
    );
    final header = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('purchase-ledger')),
        matching: find.text('الباقي'),
      ),
    );
    final amount = tester.getRect(
      find.byKey(const Key('purchase-carry-open-11')),
    );
    expect((amount.center.dx - header.center.dx).abs(), lessThan(4));
    final date = tester.getRect(find.byKey(const Key('purchase-day-date-11')));
    expect(date.center.dx, greaterThan(amount.center.dx));
    final mark = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('purchase-ledger')),
        matching: find.text('✓'),
      ),
    );
    final button = tester.getRect(find.byKey(const Key('day-correction-11')));
    expect((button.center.dx - mark.center.dx).abs(), lessThan(24));
    expect(tester.getSize(rollover).height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home and purchase separator screenshots', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await saveShot(tester, 'home-admin-light-360x800');

    tester.view.physicalSize = const Size(360, 640);
    await tester.pump();
    await saveShot(tester, 'home-admin-light-360x640');

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();
    await _toggleTheme(tester);
    await saveShot(tester, 'home-admin-dark-360x800');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    await saveShot(tester, 'home-employee-light-360x800');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-rollover-11')),
      80,
      scrollable: _verticalScrollable,
    );
    await saveShot(tester, 'purchases-separator-light');
    await _toggleTheme(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-rollover-11')),
      80,
      scrollable: _verticalScrollable,
    );
    await saveShot(tester, 'purchases-separator-dark');

    await pumpFakeApp(tester, size: const Size(1280, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-rollover-11')),
      80,
      scrollable: _verticalScrollable,
    );
    await saveShot(tester, 'purchases-separator-wide');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await saveShot(tester, 'purchases-entry-light-360x800');
    await _toggleTheme(tester);
    await saveShot(tester, 'purchases-entry-dark-360x800');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-rollover-11')),
      40,
      scrollable: _verticalScrollable,
    );
    await saveShot(tester, 'purchases-separator-dark-360');

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-rollover-11')),
      40,
      scrollable: _verticalScrollable,
    );
    await saveShot(tester, 'purchases-separator-light-360');
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-day-12')),
      80,
      scrollable: _verticalScrollable,
    );
    await saveShot(tester, 'purchases-totals-below-360');
  }, tags: const ['screenshots']);
}

final _verticalScrollable = find.descendant(
  of: find.byKey(const Key('screen-purchases')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  ),
);

void _expectSingleLineAmount(WidgetTester tester, Key key) {
  final textFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Text),
  );
  final text = tester.widget<Text>(textFinder);
  expect(text.maxLines, 1);
  expect(text.softWrap, isFalse);
  final render = tester.renderObject<RenderParagraph>(textFinder);
  final boxes = render.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.data!.length),
  );
  final tops = boxes.map((box) => box.top.round()).toSet();
  expect(tops, hasLength(1));
  expect(tester.takeException(), isNull);
}

void _expectGridFits(WidgetTester tester, {required bool settings}) {
  final scrollable = find.descendant(
    of: find.byKey(HomeDashboard.screenKey),
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(position.maxScrollExtent, 0);
  final bar = tester.getRect(find.byKey(HomeShell.bottomBarKey));
  final marks = find.byType(HomeIconMark);
  expect(marks, findsWidgets);
  for (final element in marks.evaluate()) {
    final icon = tester.getRect(find.byWidget(element.widget));
    expect(icon.height, greaterThanOrEqualTo(24));
    final tile = tester.getRect(
      find
          .ancestor(
            of: find.byWidget(element.widget),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(tile.height, greaterThanOrEqualTo(48));
    expect(tile.bottom, lessThanOrEqualTo(bar.top + 1));
    expect((icon.center.dx - tile.center.dx).abs(), lessThan(2));
  }
  if (settings) {
    expect(
      tester.getRect(find.byKey(HomeDashboard.settingsTileKey)).bottom,
      lessThanOrEqualTo(bar.top + 1),
    );
  }
}

void _expectCentered(WidgetTester tester, Key tileKey) {
  final tile = tester.getRect(find.byKey(tileKey));
  final icon = tester.getRect(
    find.descendant(
      of: find.byKey(tileKey),
      matching: find.byType(HomeIconMark),
    ),
  );
  expect((icon.center.dx - tile.center.dx).abs(), lessThan(2));
}

Future<void> _toggleTheme(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeShell.menuKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(AppStrings.themeDark));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  Scaffold.of(tester.element(find.byKey(HomeShell.menuKey))).closeDrawer();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
