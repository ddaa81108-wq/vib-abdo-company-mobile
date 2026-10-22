import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/presentation.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

void main() {
  test('dates and age phrases stay in the current Arabic wording', () {
    expect(formatIsoDate(null), AppStrings.dash);
    expect(formatIsoDate(DateTime(2026, 10, 18)), '2026-10-18');
    expect(formatIsoDate(DateTime(2026, 1, 3)), '2026-01-03');
    expect(sinceDays(null), AppStrings.dash);
    expect(sinceDays(1), 'منذ 1 أيام');
    expect(sinceDays(4), 'منذ 4 أيام');
    expect(ageCountPhrase(1), 'منذ يوم');
    expect(ageCountPhrase(2), 'منذ يومين');
    expect(ageCountPhrase(3), 'منذ 3 أيام');
    expect(ageCountPhrase(10), 'منذ 10 أيام');
    expect(ageCountPhrase(0), 'منذ 0 يومًا');
    expect(ageCountPhrase(11), 'منذ 11 يومًا');
    expect(ageCountPhrase(-1), 'منذ -1 يومًا');
  });

  testWidgets('main screens are RTL, with start alignment and mirrored icons', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await visitMainScreens(tester, (path) {
      expectRtl(tester);
      if (path == '/') _expectLatinDates(tester);
      if (path == '/notifications') _expectNoticeDirection(tester);
      if (path == '/customers/c_55') _expectBackArrow(tester);
      if (path == '/signup-info') _expectBackArrow(tester);
      if (path == '/account') _expectLogoutMirrored(tester);
    });
  });
}

void _expectLatinDates(WidgetTester tester) {
  expect(find.text('2026-10-19'), findsWidgets);
  expect(find.textContaining('آخر تحديث 2026-10-19'), findsOneWidget);
  final arabicDigits = RegExp('[٠-٩]');
  final painted = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((value) => arabicDigits.hasMatch(value));
  expect(painted, isEmpty);
}

void _expectNoticeDirection(WidgetTester tester) {
  final button = find.byKey(const Key('mark-all-read'));
  final align = find.ancestor(of: button, matching: find.byType(Align)).first;
  expect(
    tester.widget<Align>(align).alignment,
    AlignmentDirectional.centerStart,
  );
  final buttonRect = tester.getRect(button);
  final alignRect = tester.getRect(align);
  expect(buttonRect.right, closeTo(alignRect.right, 1));

  final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right).first);
  expect(chevron.textDirection, TextDirection.rtl);
  expect(
    tester.getCenter(find.byIcon(Icons.chevron_right).first).dx,
    lessThan(tester.getCenter(find.byKey(const Key('notice-headline-n_1'))).dx),
  );
}

void _expectBackArrow(WidgetTester tester) {
  final finder = find.byIcon(Icons.arrow_back);
  expect(finder, findsWidgets);
  expect(Icons.arrow_back.matchTextDirection, isTrue);
  final icon = tester.widget<Icon>(finder.first);
  final direction =
      icon.textDirection ?? Directionality.of(tester.element(finder.first));
  expect(direction, TextDirection.rtl);
  final back = tester.getCenter(finder.first);
  final scaffold = tester.getRect(find.byType(Scaffold).first);
  expect(back.dx, greaterThan(scaffold.center.dx));
}

void _expectLogoutMirrored(WidgetTester tester) {
  final icon = find.descendant(
    of: find.byKey(const Key('account-logout')),
    matching: find.byIcon(Icons.logout),
  );
  expect(icon, findsOneWidget);
  expect(Icons.logout.matchTextDirection, isFalse);
  final transform = tester.widget<Transform>(
    find.ancestor(of: icon, matching: find.byType(Transform)).first,
  );
  expect(transform.transform.storage[0], lessThan(0));
  final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right).first);
  expect(chevron.textDirection, TextDirection.rtl);
}
