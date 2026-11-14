import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_ui.dart' show go;
import 'support/pump_app.dart';

void main() {
  for (final width in const [360.0, 1280.0]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets(
        'purchase ticks sit in the middle at ${width.toInt()} scale $scale',
        (tester) async {
          await pumpFakeApp(tester, size: Size(width, 900), textScale: scale);
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/purchases');
          await tester.scrollUntilVisible(
            find.byKey(const Key('purchase-saved-mark-pe_old')),
            40,
            scrollable: _vertical,
          );
          _expectInActionCell(
            tester,
            mark: find.byKey(const Key('purchase-saved-mark-pe_old')),
            row: find.byKey(const Key('purchase-entry-pe_old')),
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('save-purchase')),
            40,
            scrollable: _vertical,
          );
          _expectInActionCell(
            tester,
            mark: find.byKey(const Key('save-purchase')),
            row: find.byKey(const Key('purchase-inline-row')),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('editing a row centers the cancel mark with the tick', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(1280, 900));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/purchases');
    await tester.tap(find.byKey(const Key('edit-pe_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-purchase')), findsOneWidget);
    final row = tester.getRect(find.byKey(const Key('purchase-inline-row')));
    final save = tester.getRect(find.byKey(const Key('save-purchase')));
    final cancel = tester.getRect(find.byKey(const Key('cancel-purchase')));
    expect((save.center.dy - row.center.dy).abs(), lessThan(3));
    expect((cancel.center.dy - row.center.dy).abs(), lessThan(3));
    // The pair stays on screen, in the pinned action column, not in the
    // off-screen end of the wide row.
    expect(save.left, greaterThanOrEqualTo(0));
    expect(cancel.right, lessThanOrEqualTo(1280));
    expect((save.center.dx - cancel.center.dx).abs(), lessThan(56));
    await tester.tap(find.byKey(const Key('cancel-purchase')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-purchase')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _expectInActionCell(
  WidgetTester tester, {
  required Finder mark,
  required Finder row,
}) {
  final markRect = tester.getRect(mark);
  final rowRect = tester.getRect(row);
  final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final dy = (markRect.center.dy - rowRect.center.dy).abs();
  expect(markRect.left, greaterThanOrEqualTo(0), reason: 'mark=$markRect');
  expect(
    markRect.right,
    lessThanOrEqualTo(screen + 1),
    reason: 'mark=$markRect',
  );
  expect(dy, lessThan(4), reason: 'mark=$markRect row=$rowRect');
}

final _vertical = find.descendant(
  of: find.byKey(const Key('screen-purchases')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  ),
);
