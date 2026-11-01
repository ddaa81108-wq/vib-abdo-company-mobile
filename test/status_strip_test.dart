import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/date_labels.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/environment_badge.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts;
import 'support/pump_app.dart';

/// Real fonts (the strip picks the date form by measuring text), so this
/// lives in its own file and does not change the other shell tests.
void main() {
  testWidgets('strip: role, Tripoli date in the centre, status; no overlap', (
    tester,
  ) async {
    for (final width in [430.0, 360.0, 320.0]) {
      for (final online in [true, false]) {
        final link = ToggleConnectivity(true);
        await tester.runAsync(loadScreenshotFonts);
        await pumpFakeApp(tester, size: Size(width, 800), connectivity: link);
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        if (!online) {
          link.setOnline(false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
        }
        final today = tripoliNow();
        final date = find.byKey(ConnectionBanner.dateKey);
        expect(date, findsOneWidget);
        final shown = tester.widget<Text>(date).data;
        expect(
          shown,
          anyOf(
            tripoliDateLabel(today),
            tripoliDateLabel(today, short: true),
            tripoliDateLabel(today, numeric: true),
          ),
        );
        // A normal phone online shows the full form.
        if (width == 430 && online) expect(shown, tripoliDateLabel(today));
        debugPrint('strip width $width online $online date "$shown"');
        final role = tester.getRect(find.byKey(HomeShell.roleKey));
        final status = tester.getRect(
          find.byKey(Key(online ? 'online-banner' : 'offline-banner')),
        );
        final dateText = find.descendant(
          of: date,
          matching: find.byType(RichText),
        );
        final painted = tester.renderObject<RenderParagraph>(dateText);
        // The date is not clipped (no ellipsis) and sits between the two.
        expect(
          painted.didExceedMaxLines,
          isFalse,
          reason: 'width $width online $online',
        );
        final dateRect = tester.getRect(date);
        expect(dateRect.right, lessThanOrEqualTo(role.left + 0.5));
        expect(dateRect.left, greaterThanOrEqualTo(status.right - 0.5));
        // Centred under the environment pill, and below it.
        expect(dateRect.center.dx, closeTo(width / 2, 1));
        final badge = tester.getRect(
          find.byKey(EnvironmentBadgeOverlay.badgeKey),
        );
        final line = tester.getRect(dateText);
        expect(
          line.top,
          greaterThanOrEqualTo(badge.bottom),
          reason: 'width $width online $online',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
