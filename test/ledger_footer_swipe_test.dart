import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';

import 'support/pump_app.dart';
import 'support/phase7_ui.dart';

void main() {
  for (final route in [
    '/customers/c_55',
    '/companies/c_co_02',
    '/libyan-deposits/c_55',
    '/egyptian-deposits/c_eg_08',
  ]) {
    for (final dark in [false, true]) {
      for (final width in [360.0, 430.0]) {
        for (final pointer in [
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
        ]) {
          testWidgets(
            '$route footer swipes both ways ${dark ? "night" : "day"} $width ${pointer.name}',
            (tester) async {
              await pumpFakeApp(tester, size: Size(width, 900));
              if (dark) {
                await tester.tap(find.byKey(LoginScreen.themeKey));
                await settle(tester);
              }
              await signIn(
                tester,
                username: 'admin.demo',
                password: 'demo-only',
              );
              await go(tester, route);
              final handle = find.byKey(const Key('ledger-swipe-handle'));
              ScrollController controller(String key) => tester
                  .widget<SingleChildScrollView>(find.byKey(Key(key)))
                  .controller!;
              final rows = controller('ledger-columns-scroll');
              final header = controller('ledger-header-scroll');
              final composer = find.byKey(const Key('movement-inline'));
              final fieldScroll = tester
                  .widget<SingleChildScrollView>(
                    find
                        .ancestor(
                          of: composer,
                          matching: find.byType(SingleChildScrollView),
                        )
                        .first,
                  )
                  .controller!;
              String total() => tester
                  .widgetList<Text>(
                    find.descendant(
                      of: find.byKey(const Key('ledger-header-balance')),
                      matching: find.byType(Text),
                    ),
                  )
                  .map((text) => text.data ?? '')
                  .join('|');
              final initialTotal = total();
              final initial = rows.offset;
              await tester.tap(handle, kind: pointer);
              await settle(tester);
              expect(
                rows.offset,
                greaterThan(initial),
                reason: 'a normal click reveals more columns',
              );
              expect(header.offset, closeTo(rows.offset, 0.5));
              expect(fieldScroll.offset, closeTo(rows.offset, 0.5));
              for (
                var i = 0;
                i < 10 && rows.offset < rows.position.maxScrollExtent - 1;
                i++
              ) {
                await tester.tap(handle, kind: pointer);
                await settle(tester);
              }
              expect(rows.offset, closeTo(rows.position.maxScrollExtent, 0.5));
              await tester.tap(handle, kind: pointer);
              await settle(tester);
              expect(
                rows.offset,
                closeTo(rows.position.minScrollExtent, 0.5),
                reason: 'clicking at the end returns to the first columns',
              );
              final dragStart = rows.offset;
              await tester.drag(handle, const Offset(220, 0), kind: pointer);
              await settle(tester);
              expect(rows.offset, greaterThan(dragStart));
              expect(header.offset, closeTo(rows.offset, 0.5));
              expect(fieldScroll.offset, closeTo(rows.offset, 0.5));
              final moved = rows.offset;
              await tester.drag(handle, const Offset(-220, 0), kind: pointer);
              await settle(tester);
              expect(rows.offset, lessThan(moved));
              for (var i = 0; i < 8; i++) {
                await tester.drag(handle, const Offset(240, 0), kind: pointer);
                await tester.pump();
              }
              await settle(tester);
              expect(rows.offset, closeTo(rows.position.maxScrollExtent, 0.5));
              expect(header.offset, closeTo(rows.offset, 0.5));
              for (var i = 0; i < 8; i++) {
                await tester.drag(handle, const Offset(-240, 0), kind: pointer);
                await tester.pump();
              }
              await settle(tester);
              expect(rows.offset, closeTo(rows.position.minScrollExtent, 0.5));
              expect(fieldScroll.offset, closeTo(rows.offset, 0.5));
              expect(total(), initialTotal);
              expect(tester.takeException(), isNull);
              await tester.pump(const Duration(seconds: 1));
            },
          );
        }
      }
    }
  }
}
