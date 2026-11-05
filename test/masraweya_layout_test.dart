import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_screen.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_share.dart';

import 'support/pump_app.dart';

void main() {
  for (final (size, scale, label) in const [
    (Size(440, 956), 1.0, 'large-phone'),
    (Size(440, 956), 1.3, 'large-phone-text'),
    (Size(1280, 900), 1.0, 'tablet'),
  ]) {
    testWidgets('masraweya $label has no overflow', (tester) async {
      await pumpFakeApp(tester, size: size, textScale: scale);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      expect(find.byKey(MasraweyaScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('masraweya-page')), findsOneWidget);
      expect(find.byKey(const Key('masraweya-summary')), findsOneWidget);
      expect(find.byKey(const Key('masraweya-work')), findsOneWidget);
      if (size.width < 900) {
        double top(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
        expect(top('masraweya-page'), lessThan(top('masraweya-summary')));
        expect(top('masraweya-summary'), lessThan(top('masraweya-work')));
      }
      expect(find.text('ت'), findsWidgets);
      expect(find.text('الإجمالي'), findsWidgets);
      expect(find.text('التسلسل'), findsNothing);
      expect(find.text('الناتج'), findsNothing);
      expect(find.text('ملخص اليوم'), findsOneWidget);
      expect(find.text('شغل اليوم'), findsOneWidget);
      expect(find.text('مشتريات اليوم'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('masraweya-work-table')),
          matching: find.text('مشتريات اليوم'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('masraweya-entry-total-0')),
          matching: find.text('3,050 ج.م'),
        ),
        findsOneWidget,
      );
      expect(find.text('إجمالي الصف = القيمة + العمولة'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapAddRow(tester);
      await tapAddRow(tester);
      expect(
        find.byKey(const Key('masraweya-entry-value-field-2')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('add row grows the same table and focus moves across it', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 1200));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    final before = tester.getRect(
      find.byKey(const Key('masraweya-work-table')),
    );
    await tester.tap(find.byKey(const Key('masraweya-add-row')));
    await settle(tester);
    expect(
      find.byKey(const Key('masraweya-entry-value-field-1')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    final after = tester.getRect(find.byKey(const Key('masraweya-work-table')));
    expect(after.height, greaterThan(before.height));

    FocusNode nodeOf(Key key) {
      return tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode;
    }

    final value = const Key('masraweya-entry-value-field-0');
    final commission = const Key('masraweya-entry-commission-field-0');
    final nextValue = const Key('masraweya-entry-value-field-1');
    await tester.tap(find.byKey(value));
    await tester.pump();
    expect(nodeOf(value).hasFocus, isTrue);
    nodeOf(commission).requestFocus();
    await tester.pump();
    expect(nodeOf(commission).hasFocus, isTrue);
    nodeOf(nextValue).requestFocus();
    await tester.pump();
    expect(nodeOf(nextValue).hasFocus, isTrue);
    expect(find.byKey(const Key('masraweya-work-table')), findsOneWidget);
  });

  testWidgets('keyboard inset keeps the focused field on screen', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(440, 956));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');
    final field = find.byKey(const Key('masraweya-entry-commission-field-0'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    final rect = tester.getRect(field);
    const keyboardTop = 956 - 340;
    expect(rect.bottom, lessThanOrEqualTo(keyboardTop + 1));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(find.byKey(const Key('masraweya-work-table')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary capture excludes the work table and the share control', (
    tester,
  ) async {
    Uint8List? shared;
    await pumpFakeApp(
      tester,
      size: const Size(440, 956),
      overrides: [
        masraweyaBoundaryCaptureProvider.overrideWithValue(
          (boundary) async => Uint8List.fromList(const [7, 7, 7]),
        ),
        masraweyaSummarySharerProvider.overrideWith(
          (ref) => (png, name) async {
            shared = png;
            expect(name, 'masraweya-summary.png');
          },
        ),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/masraweya');

    final capture = find.byKey(const Key('masraweya-summary-capture'));
    expect(capture, findsOneWidget);
    expect(
      find.descendant(of: capture, matching: find.text('مشتريات اليوم')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capture, matching: find.text('إجمالي شغل اليوم')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capture, matching: find.text('القيمة السابقة')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: capture, matching: find.text('الرصيد المتبقي')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: capture,
        matching: find.byKey(const Key('masraweya-work-table')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: capture,
        matching: find.byKey(const Key('masraweya-share-summary')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: capture, matching: find.text('شغل اليوم')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('masraweya-share-summary')));
    await tester.pump();
    await tester.pump();
    expect(shared, Uint8List.fromList(const [7, 7, 7]));
    expect(tester.renderObject(capture).runtimeType, isNot(RenderView));
  });
}

Future<void> tapAddRow(WidgetTester tester) async {
  final add = find.byKey(const Key('masraweya-add-row'));
  final list = find.byKey(MasraweyaScreen.screenKey);
  await tester.ensureVisible(add);
  await tester.pump();
  final view = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var i = 0; i < 5; i++) {
    final rect = tester.getRect(add);
    if (rect.center.dy < view - 96 && rect.center.dy > 72) break;
    await tester.drag(list, Offset(0, rect.center.dy > view - 96 ? -180 : 180));
    await tester.pump();
  }
  await tester.tap(add);
  await settle(tester);
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
