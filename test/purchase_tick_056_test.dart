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
            scale: scale,
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
            scale: scale,
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
    final pair = (save.center.dx + cancel.center.dx) / 2;
    expect((pair - (row.left + 96 / 2)).abs(), lessThan(4));
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
  required double scale,
}) {
  final markRect = tester.getRect(mark);
  final rowRect = tester.getRect(row);
  final cellCenterX = rowRect.left + (96 * scale) / 2;
  final dx = (markRect.center.dx - cellCenterX).abs();
  final dy = (markRect.center.dy - rowRect.center.dy).abs();
  expect(
    dx,
    lessThan(4),
    reason: 'mark=$markRect row=$rowRect expectedX=$cellCenterX',
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
