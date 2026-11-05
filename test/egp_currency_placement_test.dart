import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  testWidgets('ج.م is physically left of the digits under RTL', (tester) async {
    await pump(tester, const MoneyText('3,050 ج.م'));

    final symbol = tester.getRect(find.text('ج.م'));
    final number = tester.getRect(find.text('3,050'));
    expect(symbol.center.dx, lessThan(number.center.dx));
    expect(symbol.right, lessThanOrEqualTo(number.left + 1));
    expect(tester.widget<Text>(find.text('3,050')).data, '3,050');
    expect(
      tester.widget<Text>(find.text('3,050')).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('د.ل stays on the number side it already used', (tester) async {
    await pump(tester, const MoneyText('320 د.ل'));
    final line = tester.widget<Text>(find.text('320 د.ل'));
    expect(line.data, '320 د.ل');
  });
}
