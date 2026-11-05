import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_screen.dart';

import 'support/pump_app.dart';

// Ali, 2026-11-05: المصراوية inline table, fixed page, row navigation.
void main() {
  for (final (size, scale, label) in const [
    (Size(430, 2200), 1.0, 'phone'),
    (Size(1280, 1600), 1.0, 'tablet'),
    (Size(430, 2600), 1.6, 'phone-large-text'),
  ]) {
    testWidgets('masraweya layout $label x$scale no overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFakeApp(tester, size: size);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      expect(find.byKey(MasraweyaScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('masraweya-page')), findsOneWidget);
      expect(find.byKey(const Key('masraweya-summary')), findsOneWidget);
      expect(find.byKey(const Key('masraweya-work')), findsOneWidget);
      // Image-3 order on phone: page → ملخص → شغل.
      if (size.width < 900) {
        double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
        expect(top('masraweya-page'), lessThan(top('masraweya-summary')));
        expect(top('masraweya-summary'), lessThan(top('masraweya-work')));
      }
      expect(find.byKey(const Key('masraweya-work-table')), findsOneWidget);
      expect(find.text('التسلسل'), findsOneWidget);
      expect(find.text('القيمة'), findsWidgets);
      expect(find.text('العمولة'), findsWidgets);
      expect(find.text('الناتج'), findsOneWidget);
      expect(find.text('ملخص اليوم'), findsOneWidget);
      expect(find.text('شغل اليوم'), findsOneWidget);
      expect(find.byKey(const Key('masraweya-foot')), findsOneWidget);
      // الناتج stays a dash (no device formula).
      expect(
        find.descendant(
          of: find.byKey(const Key('masraweya-work-table')),
          matching: find.text('—'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('+ صف grows the same table downward', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    expect(
      find.byKey(const Key('masraweya-entry-value-field-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('masraweya-entry-value-field-1')),
      findsNothing,
    );
    final before = tester.getRect(
      find.byKey(const Key('masraweya-work-table')),
    );
    await tester.tap(find.byKey(const Key('masraweya-add-row')));
    await settle(tester);
    expect(
      find.byKey(const Key('masraweya-entry-value-field-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('masraweya-work-table')), findsOneWidget);
    final after = tester.getRect(find.byKey(const Key('masraweya-work-table')));
    expect(after.top, before.top);
    expect(after.height, greaterThan(before.height));
  });

  testWidgets('typing in a row keeps the table position', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    final table = find.byKey(const Key('masraweya-work-table'));
    final before = tester.getRect(table);
    final field = find.byKey(const Key('masraweya-entry-value-field-0'));
    await tester.tap(field);
    await tester.pump();
    // Simulate the on-screen keyboard without moving the page (viewInsets
    // are zeroed on this screen).
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.enterText(field, '3200');
    await tester.pump();
    expect(tester.getRect(table), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus moves value → commission → next row', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    await tester.tap(find.byKey(const Key('masraweya-add-row')));
    await settle(tester);
    FocusNode nodeOf(Key key) {
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      );
      return editable.focusNode;
    }

    final v0 = const Key('masraweya-entry-value-field-0');
    final c0 = const Key('masraweya-entry-commission-field-0');
    final v1 = const Key('masraweya-entry-value-field-1');
    await tester.tap(find.byKey(v0));
    await tester.pump();
    expect(nodeOf(v0).hasFocus, isTrue);
    nodeOf(c0).requestFocus();
    await tester.pump();
    expect(nodeOf(c0).hasFocus, isTrue);
    nodeOf(v1).requestFocus();
    await tester.pump();
    expect(nodeOf(v1).hasFocus, isTrue);
  });

  testWidgets('masraweya stays clear on phone', (tester) async {
    await pumpFakeApp(tester, size: const Size(430, 2400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    expect(tester.takeException(), isNull);
  });
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
