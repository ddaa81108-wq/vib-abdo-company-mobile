import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'pump_app.dart';

/// Shell routes a signed-in admin can open, plus the screens beside the shell.
const shellScreens = <String, Key>{
  '/': Key('home-dashboard'),
  '/search': Key('screen-search'),
  '/customers': Key('screen-customers'),
  '/companies': Key('screen-companies'),
  '/customers/c_55': Key('screen-ledger-customers'),
  '/companies/c_55': Key('screen-ledger-companies'),
  '/libyan-deposits': Key('screen-libyan-deposits'),
  '/egyptian-deposits': Key('screen-egyptian-deposits'),
  '/purchases': Key('screen-purchases'),
  '/collections': Key('screen-collections'),
  '/treasury': Key('screen-treasury'),
  '/reports': Key('screen-reports'),
  '/masraweya': Key('screen-masraweya'),
  '/settings': Key('screen-settings'),
  '/settings/employee-totals': Key('screen-employee-totals'),
  '/account': Key('screen-account'),
  '/notifications': Key('screen-notifications'),
  '/forbidden': Key('screen-forbidden'),
};

const loggedOutScreens = <String, Key>{
  '/login': Key('login-screen'),
  '/signup-info': Key('signup-info-screen'),
};

const extraSignedInScreens = <String, Key>{
  '/account/password': Key('change-password-screen'),
};

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byKey(HomeShell.shellKey))).go(path);
  await settle(tester);
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

void expectQuiet(WidgetTester tester, String label) {
  final errors = <Object?>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    errors.add(error);
  }
  expect(errors, isEmpty, reason: '$label $errors');
}

void expectThemeApplied(WidgetTester tester, Brightness brightness) {
  final theme = Theme.of(tester.element(find.byType(Scaffold).first));
  final expected = buildAppTheme(brightness);
  expect(theme.brightness, brightness);
  expect(theme.scaffoldBackgroundColor, expected.scaffoldBackgroundColor);
  expect(theme.colorScheme.primary, expected.colorScheme.primary);
  expect(theme.colorScheme.onSurface, expected.colorScheme.onSurface);
  expect(theme.textTheme.bodyMedium?.color, expected.colorScheme.onSurface);
}

/// Signs in as admin and opens every main screen. [check] runs on the settled
/// frame, including login and the signup note before sign-in.
Future<void> visitMainScreens(
  WidgetTester tester,
  void Function(String path) check,
) async {
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  for (final entry in loggedOutScreens.entries) {
    router.go(entry.key);
    await settle(tester);
    expect(find.byKey(entry.value), findsOneWidget, reason: entry.key);
    check(entry.key);
    expectQuiet(tester, entry.key);
  }

  router.go('/login');
  await settle(tester);
  await signIn(tester, username: 'admin.demo', password: 'demo-only');

  for (final entry in {...shellScreens, ...extraSignedInScreens}.entries) {
    router.go(entry.key);
    await settle(tester);
    expect(find.byKey(entry.value), findsOneWidget, reason: entry.key);
    check(entry.key);
    expectQuiet(tester, entry.key);
  }
}

/// Text whose painted color is below [minRatio] against the nearest opaque
/// background. Empty when the screen is readable at that bar.
List<String> unreadableText(WidgetTester tester, {double minRatio = 3}) {
  final failures = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final sample = (text.data ?? text.textSpan?.toPlainText() ?? '').trim();
    if (sample.isEmpty) continue;
    final render = element.renderObject;
    if (render is! RenderBox || !render.hasSize || render.size.isEmpty) {
      continue;
    }
    if (_disabled(element)) continue;
    final foreground = _textColor(element, text);
    if (foreground == null || foreground.a == 0) continue;
    final background = _backgroundOf(element);
    if (background == null) continue;
    final painted = foreground.a >= 1
        ? foreground
        : _composite(foreground, background);
    final ratio = _contrast(painted, background);
    if (ratio < minRatio) {
      failures.add(
        '"${_clip(sample)}" '
        '${_hex(painted)} on ${_hex(background)} '
        '${ratio.toStringAsFixed(2)}:1',
      );
    }
  }
  return failures;
}

String _clip(String value) =>
    value.length <= 32 ? value : '${value.substring(0, 32)}…';

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

bool _disabled(Element element) {
  var disabled = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is ButtonStyleButton && widget.onPressed == null) {
      disabled = true;
      return false;
    }
    if (widget is IconButton && widget.onPressed == null) {
      disabled = true;
      return false;
    }
    return true;
  });
  return disabled;
}

Color? _textColor(Element element, Text text) {
  final direct = text.style?.color;
  if (direct != null) return direct;
  final span = text.textSpan;
  if (span is TextSpan && span.style?.color != null) return span.style!.color;
  return DefaultTextStyle.of(element).style.color;
}

Color? _backgroundOf(Element start) {
  Color? found;
  start.visitAncestorElements((ancestor) {
    final painted = _paintOf(ancestor);
    if (painted == null) return true;
    found = painted;
    return false;
  });
  return found;
}

Color? _paintOf(Element element) {
  final widget = element.widget;
  if (widget is Ink) {
    return _decorationColor(widget.decoration);
  }
  if (widget is DecoratedBox) {
    return _decorationColor(widget.decoration);
  }
  if (widget is ColoredBox && widget.color.a >= 0.9) return widget.color;
  if (widget is Material && widget.type != MaterialType.transparency) {
    final color = widget.color ?? Theme.of(element).colorScheme.surface;
    if (color.a >= 0.9) return color;
  }
  if (widget is Scaffold) {
    return widget.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;
  }
  return null;
}

Color? _decorationColor(Decoration? decoration) {
  if (decoration is! BoxDecoration) return null;
  final color = decoration.color;
  if (color != null && color.a >= 0.9) return color;
  final gradient = decoration.gradient;
  if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
    return gradient.colors.last;
  }
  return null;
}

Color _composite(Color foreground, Color background) {
  final alpha = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(_luminance(foreground), _luminance(background));
  final darker = math.min(_luminance(foreground), _luminance(background));
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  return 0.2126 * _linear(color.r) +
      0.7152 * _linear(color.g) +
      0.0722 * _linear(color.b);
}

double _linear(double channel) {
  if (channel <= 0.04045) return channel / 12.92;
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}
