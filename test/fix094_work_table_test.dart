import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  for (final scale in const [1.0, 2.0]) {
    testWidgets('work columns match at 360 scale $scale', (tester) async {
      const width = 360.0;
      await pumpFakeApp(
        tester,
        size: const Size(width, 1200),
        textScale: scale,
      );
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/masraweya');
      await tester.ensureVisible(find.byKey(const Key('masraweya-work-table')));
      await tester.pump();

      Rect box(String key) => tester.getRect(find.byKey(Key(key)));
      final value = box('frame-masraweya-entry-0');
      final commission = box('frame-masraweya-entry-commission-0');
      final total = box('frame-masraweya-entry-total-0');

      expect((value.width - commission.width).abs(), lessThan(1));
      expect((value.width - total.width).abs(), lessThan(1));
      expect((value.height - commission.height).abs(), lessThan(1));
      expect((value.height - total.height).abs(), lessThan(1));
      for (final rect in [value, commission, total]) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
