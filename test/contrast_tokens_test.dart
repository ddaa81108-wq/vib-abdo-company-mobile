import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'support/pump_app.dart';

/// WCAG 2.x relative luminance. [Color.r], [Color.g], and [Color.b] are 0–1.
double _linear(double channel) {
  if (channel <= 0.04045) return channel / 12.92;
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double contrastRatio(Color foreground, Color background) {
  final lighter = _luminance(foreground);
  final darker = _luminance(background);
  final top = math.max(lighter, darker);
  final bottom = math.min(lighter, darker);
  return (top + 0.05) / (bottom + 0.05);
}

double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

/// 18pt regular (24px) or 14pt bold (18.66px). 18px bold is still normal text.
bool _isLargeText(TextStyle style) {
  final size = style.fontSize ?? 14;
  final bold =
      (style.fontWeight ?? FontWeight.w400).value >= FontWeight.w700.value;
  return size >= 24 || (bold && size >= 18.66);
}

double _aaMinimum(TextStyle style) => _isLargeText(style) ? 3 : 4.5;

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void _expectContrast(Color foreground, Color background, double minimum) {
  final ratio = contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason:
        '${_hex(foreground)} on ${_hex(background)} is '
        '${ratio.toStringAsFixed(2)}:1, need $minimum:1',
  );
}

void _expectTextContrast(Text text, Color background) {
  final style = text.style;
  expect(style?.color, isNotNull);
  expect(style?.fontSize, isNotNull);
  _expectContrast(style!.color!, background, _aaMinimum(style));
}

void _expectSameHue(Color next, Color previous) {
  final delta =
      (HSVColor.fromColor(next).hue - HSVColor.fromColor(previous).hue).abs();
  final wrapped = delta > 180 ? 360 - delta : delta;
  expect(
    wrapped,
    lessThan(5),
    reason: '${_hex(next)} left the hue of ${_hex(previous)}',
  );
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _darken(WidgetTester tester) async {
  await tester.tap(find.byKey(LoginScreen.themeKey));
  await _settle(tester);
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await _settle(tester);
}

class _ForegroundProbe extends TextButton {
  const _ForegroundProbe({
    required super.onPressed,
    super.style,
    required super.child,
  });

  Color? enabledForeground(BuildContext context) {
    return defaultStyleOf(context)
        .merge(style)
        .foregroundColor
        ?.resolve(const <WidgetState>{});
  }
}

Color _buttonForeground(WidgetTester tester, Finder finder) {
  final button = tester.widget<TextButton>(finder);
  expect(
    button.onPressed,
    isNotNull,
    reason: 'disabled buttons use a different ink',
  );
  final color = _ForegroundProbe(
    onPressed: button.onPressed,
    style: button.style,
    child: button.child ?? const SizedBox.shrink(),
  ).enabledForeground(tester.element(finder));
  expect(color, isNotNull);
  return color!;
}

void main() {
  testWidgets('DEF-020 login brand meets AA on the scaffold in both themes', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pumpFakeApp(tester, size: const Size(360, 780));
      if (dark) await _darken(tester);
      final mark = tester.widget<Text>(find.text(AppStrings.brandMark));
      final word = tester.widget<Text>(find.text(AppStrings.brandWord));
      final theme = Theme.of(tester.element(find.text(AppStrings.brandMark)));
      final base = theme.extension<AppSidebarPalette>()!.base;
      final scaffold = theme.scaffoldBackgroundColor;

      expect(mark.style?.color, base);
      expect(word.style?.color, base);
      expect(mark.style?.fontSize, 40);
      expect(word.style?.fontSize, 18);
      expect(_isLargeText(mark.style!), isTrue);
      expect(_isLargeText(word.style!), isFalse);
      _expectTextContrast(mark, scaffold);
      _expectTextContrast(word, scaffold);
      if (dark) {
        expect(base, const Color(0xFFEAB600));
        expect(scaffold, const Color(0xFF0D1522));
      } else {
        expect(base, const Color(0xFF7C6100));
        expect(scaffold, const Color(0xFFE5EDF6));
        _expectSameHue(base, AppSidebarPalette.gold.base);
      }
    }
  });

  testWidgets(
    'DEF-021 rail role uses sidebar shine and the phone role stays onSurface',
    (tester) async {
      await pumpFakeApp(tester, size: const Size(800, 900));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      _expectRole(tester, onSidebar: true, dark: false);

      await tester.tap(find.byTooltip(AppStrings.themeDark));
      await _settle(tester);
      _expectRole(tester, onSidebar: true, dark: true);

      await pumpFakeApp(tester, size: const Size(360, 780));
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      _expectRole(tester, onSidebar: false, dark: false);
      await _openDrawer(tester);
      _expectDrawerWord(tester, dark: false);

      await pumpFakeApp(tester, size: const Size(360, 780));
      await _darken(tester);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      _expectRole(tester, onSidebar: false, dark: true);
      await _openDrawer(tester);
      _expectDrawerWord(tester, dark: true);
    },
  );

  testWidgets('DEF-022 primary text, cash ink, and the cash fill meet AA', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      late ThemeData theme;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      _expectTokenPairs(theme);
    }

    await pumpFakeApp(tester, size: const Size(800, 1400));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await _expectRenderedInk(tester, dark: false);
    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await _settle(tester);
    await _expectRenderedInk(tester, dark: true);
  });
}

void _expectRole(
  WidgetTester tester, {
  required bool onSidebar,
  required bool dark,
}) {
  expect(find.byKey(HomeShell.roleKey), findsOneWidget);
  final role = tester.widget<Text>(find.byKey(HomeShell.roleKey));
  final theme = Theme.of(tester.element(find.byKey(HomeShell.roleKey)));
  final shine = theme.extension<AppSidebarPalette>()!.shine;
  final onSurface = theme.colorScheme.onSurface;
  final background = onSidebar
      ? theme.extension<AppColors>()!.sidebarBg
      : theme.scaffoldBackgroundColor;

  expect(shine, const Color(0xFFFFFDE0));
  expect(role.style?.fontSize, 13);
  if (onSidebar) {
    expect(role.style?.color, shine);
    expect(role.style?.color, isNot(onSurface));
    expect(
      background,
      dark ? const Color(0xFF101B2A) : const Color(0xFF102A26),
    );
  } else {
    expect(role.style?.color, onSurface);
    expect(role.style?.color, isNot(shine));
  }
  _expectTextContrast(role, background);
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeShell.menuKey));
  await _settle(tester);
}

void _expectDrawerWord(WidgetTester tester, {required bool dark}) {
  final word = tester.widget<Text>(find.text(AppStrings.brandWord));
  final theme = Theme.of(tester.element(find.text(AppStrings.brandWord)));
  final palette = theme.extension<AppSidebarPalette>()!;
  expect(word.style?.color, palette.bright);
  expect(word.style?.color, isNot(palette.base));
  expect(word.style?.color, const Color(0xFFFFDB35));
  expect(word.style?.fontSize, 20);
  _expectTextContrast(
    word,
    dark ? const Color(0xFF101B2A) : const Color(0xFF102A26),
  );
}

void _expectTokenPairs(ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  final scheme = theme.colorScheme;
  final status = theme.extension<AppStatusColors>()!;
  final colors = theme.extension<AppColors>()!;
  final sidebar = theme.extension<AppSidebarPalette>()!;
  const white = Color(0xFFFFFFFF);

  expect(status.cashPositive, const Color(0xFF087A50));
  expect(status.cashNegative, const Color(0xFFB43131));
  _expectContrast(white, status.cashPositive, 4.5);
  _expectContrast(status.cashPositiveText, scheme.surface, 4.5);
  for (final tone in status.dayTones) {
    _expectContrast(scheme.primary, tone, 4.5);
    _expectContrast(status.cashPositiveText, tone, 4.5);
  }
  _expectContrast(scheme.primary, scheme.surface, 4.5);
  _expectContrast(scheme.primary, theme.scaffoldBackgroundColor, 4.5);
  _expectContrast(scheme.primary, scheme.surfaceContainerHigh, 4.5);
  _expectContrast(scheme.onPrimary, scheme.primary, 4.5);
  _expectContrast(sidebar.shine, colors.sidebarBg, 4.5);

  if (dark) {
    expect(scheme.primary, const Color(0xFF36B496));
    expect(scheme.tertiary, scheme.primary);
    expect(scheme.surfaceTint, scheme.primary);
    expect(scheme.onPrimary, const Color(0xFF041510));
    expect(scheme.surface, const Color(0xFF172333));
    expect(status.dayTones[2], const Color(0xFF1A2C24));
    expect(status.cashPositiveText, const Color(0xFF0CB677));
    expect(sidebar.base, const Color(0xFFEAB600));
    _expectSameHue(scheme.primary, const Color(0xFF247763));
    _expectSameHue(status.cashPositiveText, status.cashPositive);
    _expectContrast(scheme.primary, const Color(0xFF172333), 4.5);
    _expectContrast(scheme.primary, const Color(0xFF1A2C24), 4.5);
    _expectContrast(status.cashPositiveText, const Color(0xFF172333), 4.5);
  } else {
    expect(scheme.primary, const Color(0xFF175F50));
    expect(scheme.inversePrimary, const Color(0xFF247763));
    expect(status.cashPositiveText, const Color(0xFF087A50));
    expect(sidebar.base, const Color(0xFF7C6100));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFE5EDF6));
    _expectContrast(sidebar.base, theme.scaffoldBackgroundColor, 4.5);
    _expectContrast(scheme.primary, white, 4.5);
  }
}

Future<void> _expectRenderedInk(
  WidgetTester tester, {
  required bool dark,
}) async {
  await _go(tester, '/');
  final theme = Theme.of(tester.element(find.byKey(HomeShell.shellKey)));
  final scheme = theme.colorScheme;
  final status = theme.extension<AppStatusColors>()!;
  final action = find.byKey(const Key('show-all-customers'));
  expect(action, findsOneWidget);
  final foreground = _buttonForeground(tester, action);
  expect(foreground, scheme.primary);
  _expectContrast(foreground, theme.scaffoldBackgroundColor, 4.5);
  if (dark) {
    expect(foreground, const Color(0xFF36B496));
  } else {
    expect(foreground, const Color(0xFF175F50));
  }

  await _go(tester, '/treasury');
  final card = tester.widget<Card>(find.byKey(const Key('active-cash-card')));
  expect(card.color, const Color(0xFF087A50));
  final title = tester.widget<Text>(find.text(AppStrings.activeCash));
  expect(title.style?.color, status.onStatus);
  _expectContrast(title.style!.color!, card.color!, 4.5);

  final entry = find.byKey(const Key('cash-entry-ce_1'));
  expect(entry, findsOneWidget);
  final inks = tester
      .widgetList<Text>(find.descendant(of: entry, matching: find.byType(Text)))
      .where((text) => text.style?.color == status.cashPositiveText);
  expect(inks, isNotEmpty);
  final surface = theme.cardTheme.color ?? scheme.surface;
  _expectContrast(status.cashPositiveText, surface, 4.5);

  await _go(tester, '/purchases');
  final edit = find.byKey(const Key('edit-pe_1'));
  expect(edit, findsOneWidget);
  final editInk = _buttonForeground(tester, edit);
  expect(editInk, scheme.primary);
  final purchaseCard = tester.widget<Card>(
    find.ancestor(of: edit, matching: find.byType(Card)).first,
  );
  final band = purchaseCard.color ?? surface;
  _expectContrast(editInk, band, 4.5);
  if (dark) {
    expect(status.dayTones, contains(band));
  }
}
