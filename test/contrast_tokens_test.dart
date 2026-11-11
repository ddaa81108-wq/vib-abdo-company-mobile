import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/bars_style.dart';
import 'package:flutter_api_layer/api_layer.dart' show SectionKey;
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

/// DEF-023 is the login brand, DEF-024 is the light sidebar role, and DEF-025
/// is dark primary text plus cashPositive. DEF-026 is the light secondary text.
/// DEF-020 through DEF-022 are other defects in QA's registry.
void main() {
  testWidgets('DEF-023 login word and greeting meet AA on the cream card', (
    tester,
  ) async {
    const card = Color(0xFFF8F4EC);
    const navy = Color(0xFF071525);
    for (final dark in [false, true]) {
      await pumpFakeApp(tester, size: const Size(360, 780));
      if (dark) await _darken(tester);
      final word = tester.widget<Text>(find.text(AppStrings.brandWord));
      final hello = tester.widget<Text>(find.text('أهلًا بك'));
      final scaffold = tester.widget<Scaffold>(
        find.byKey(LoginScreen.screenKey),
      );

      expect(word.style?.color, navy);
      expect(hello.style?.color, const Color(0xFF16130C));
      expect(word.style?.fontSize, 22);
      expect(_isLargeText(word.style!), isTrue);
      expect(_isLargeText(hello.style!), isTrue);
      _expectTextContrast(word, card);
      _expectTextContrast(hello, card);
      expect(scaffold.backgroundColor, const Color(0xFF07111C));
      expect(find.text('8'), findsNothing);
      expect(find.text('طلب حساب'), findsNothing);
    }
  });

  testWidgets(
    'DEF-024 rail role uses sidebar shine and the phone role stays onSurface',
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

  testWidgets('DEF-025 primary text, cash ink, and the cash fill meet AA', (
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

  testWidgets(
    'DEF-026 light onSurfaceVariant meets AA on the four measured surfaces',
    (tester) async {
      const previous = Color(0xFF6D7C77);
      const ink = Color(0xFF5B6B80);
      const surfaces = <Color>[
        Color(0xFFF5F7FB),
        Color(0xFFFFFFFF),
        Color(0xFFE8F5EC),
        Color(0xFFE8EFFE),
      ];
      final light = buildAppTheme();
      final dark = buildAppTheme(Brightness.dark);

      expect(light.colorScheme.onSurfaceVariant, ink);
      expect(dark.colorScheme.onSurfaceVariant, const Color(0xFF94A3B8));
      expect(light.colorScheme.outline, const Color(0xFFE4E8F1));
      expect(light.colorScheme.outlineVariant, const Color(0xFFEEF1F6));
      expect(light.colorScheme.outline, isNot(previous));
      expect(light.colorScheme.outline, isNot(ink));
      for (final surface in surfaces) {
        _expectContrast(ink, surface, 4.5);
      }

      await pumpFakeApp(tester, size: const Size(360, 780));
      final field = tester.widget<TextField>(
        find.byKey(LoginScreen.usernameKey),
      );
      final hint = Text('', style: field.decoration?.hintStyle);
      expect(hint.style?.color, const Color(0xFF4E463C));
      expect(hint.style?.fontSize, 14);
      expect(_isLargeText(hint.style!), isFalse);
      _expectTextContrast(hint, const Color(0xFFF1EBE0));
    },
  );
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
      // Phone: the role sits in the status strip at the top.
      : stripLook(
          tester.element(find.byKey(HomeShell.roleKey)),
          online: true,
        ).background;

  expect(shine, dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B));
  expect(role.style?.fontSize, 13);
  if (onSidebar) {
    expect(role.style?.color, shine);
    expect(role.style?.color, isNot(onSurface));
    expect(
      background,
      dark ? const Color(0xFF0B1020) : const Color(0xFFF5F7FB),
    );
  } else {
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
  expect(
    word.style?.color,
    dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
  );
  expect(word.style?.fontSize, 20);
  _expectTextContrast(word, theme.extension<AppColors>()!.sidebarBg);
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
    expect(scheme.primary, const Color(0xFF60A5FA));
    expect(scheme.surfaceTint, scheme.primary);
    expect(scheme.onPrimary, const Color(0xFF0B1020));
    expect(scheme.surface, const Color(0xFF131A2C));
    expect(status.dayTones[2], const Color(0xFF13261E));
    expect(status.cashPositiveText, const Color(0xFF0CB677));
    expect(sidebar.base, const Color(0xFF60A5FA));
    _expectSameHue(status.cashPositiveText, status.cashPositive);
    _expectContrast(scheme.primary, const Color(0xFF131A2C), 4.5);
    _expectContrast(scheme.primary, const Color(0xFF13261E), 4.5);
    _expectContrast(status.cashPositiveText, const Color(0xFF131A2C), 4.5);
  } else {
    expect(scheme.primary, const Color(0xFF2563EB));
    expect(scheme.inversePrimary, const Color(0xFF93C5FD));
    expect(status.cashPositiveText, const Color(0xFF087A50));
    expect(sidebar.base, const Color(0xFF2563EB));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FB));
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
  // Home icon grid: ink label and tinted icon on the tile card.
  final tileLabel = tester.widget<Text>(
    find.byKey(const Key('home-tile-label-customers')),
  );
  final tileIcon = tester.widget<Icon>(
    find.descendant(
      of: find.byKey(HomeShell.sectionKey(SectionKey.customers)),
      matching: find.byType(Icon),
    ),
  );
  final look = theme.extension<AppLook>()!;
  // Customers tile: glossy blue; check both ends of its gradient.
  for (final tileColor in [look.glossBlue.top, look.glossBlue.bottom]) {
    _expectContrast(tileLabel.style!.color!, tileColor, 4.5);
    _expectContrast(tileIcon.color!, tileColor, 3);
  }
  // «عرض الكل» left home; the primary ink is still checked on /purchases.
  expect(
    scheme.primary,
    dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
  );

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
  final row = tester.widget<DecoratedBox>(
    find.ancestor(of: edit, matching: find.byType(DecoratedBox)).first,
  );
  final band = (row.decoration as BoxDecoration).color ?? surface;
  _expectContrast(editInk, band, 4.5);
}
