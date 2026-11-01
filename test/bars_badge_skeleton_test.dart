import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/notifications/unread_badge.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

double _channel(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Future<void> _toDark(WidgetTester tester) async {
  ProviderScope.containerOf(tester.element(find.byKey(HomeShell.shellKey)))
      .read(themeModeProvider.notifier)
      .toggle();
  await settle(tester);
}

void main() {
  for (final size in const [Size(320, 568), Size(430, 932)]) {
    for (final scale in const [1.0, 2.0]) {
      for (final dark in [false, true]) {
        final tag =
            '${size.width.toInt()}x${size.height.toInt()} x$scale '
            '${dark ? 'dark' : 'light'}';
        testWidgets('bottom bar, bell badge and skeleton, $tag', (
          tester,
        ) async {
          await pumpFakeApp(tester, size: size, textScale: scale);
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          if (dark) await _toDark(tester);
          expect(tester.takeException(), isNull, reason: tag);
          final theme = Theme.of(
            tester.element(find.byKey(HomeShell.shellKey)),
          );
          expect(theme.brightness, dark ? Brightness.dark : Brightness.light);

          // Bar labels: one line each, scaled at most 1.3x, inside the bar.
          final bar = tester.getRect(find.byType(PhoneBottomNav));
          expect(bar.bottom, lessThanOrEqualTo(size.height), reason: tag);
          final labels = find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'bottom-tab-label-',
                ),
          );
          expect(labels, findsNWidgets(5));
          for (final element in labels.evaluate()) {
            final text = element.widget as Text;
            expect(text.maxLines, 1, reason: tag);
            expect(text.softWrap, isFalse, reason: tag);
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse, reason: tag);
            expect(
              MediaQuery.textScalerOf(element).scale(10),
              lessThanOrEqualTo(10 * kTabLabelMaxScale + 0.001),
              reason: tag,
            );
            final rect = tester.getRect(find.byWidget(text));
            expect(bar.contains(rect.topLeft), isTrue, reason: tag);
            expect(bar.contains(rect.bottomRight), isTrue, reason: tag);
            // One line high (no wrapped second line).
            expect(
              rect.height,
              lessThan(11 * kTabLabelMaxScale * 2),
              reason: '${text.data} $tag',
            );
          }

          // Bell badge: at the bell's top end corner, not over its centre.
          final badge = find.byKey(UnreadBadge.badgeKey);
          expect(badge, findsOneWidget, reason: 'fake account has unread');
          final pill = tester.getRect(
            find.ancestor(of: badge, matching: find.byType(Badge)).first,
          );
          final bell = tester.getRect(
            find.descendant(
              of: find.byKey(UnreadBadge.buttonKey),
              matching: find.byType(Icon),
            ),
          );
          expect(pill.contains(bell.center), isFalse, reason: tag);
          // RTL: the end corner is the left one; the pill sits above it.
          expect(pill.center.dx, lessThan(bell.left + 6), reason: tag);
          expect(pill.center.dy, lessThan(bell.top + 4), reason: tag);
          // It stays in the bell button's own box (not over its neighbours).
          final button = tester.getRect(find.byKey(UnreadBadge.buttonKey));
          expect(
            pill.left,
            greaterThanOrEqualTo(button.left - 0.5),
            reason: tag,
          );
          expect(pill.top, greaterThanOrEqualTo(button.top - 0.5), reason: tag);
          final overlap = pill.intersect(bell);
          final covered = overlap.width <= 0 || overlap.height <= 0
              ? 0.0
              : overlap.width * overlap.height;
          expect(
            covered,
            lessThan(bell.width * bell.height * 0.1),
            reason: tag,
          );
          expect(
            MediaQuery.textScalerOf(tester.element(badge)).scale(10),
            lessThanOrEqualTo(12.001),
            reason: tag,
          );

          // Skeleton: visible against the page and the cards.
          final shade = skeletonColor(theme);
          expect(
            _contrast(shade, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(1.25),
            reason: 'page $tag',
          );
          expect(
            _contrast(
              shade,
              theme.cardTheme.color ?? theme.colorScheme.surface,
            ),
            greaterThanOrEqualTo(1.25),
            reason: 'card $tag',
          );
          expect(tester.takeException(), isNull, reason: tag);
        });
      }
    }
  }
}
