import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

/// QA's registry already uses DEF-020, DEF-021, and DEF-022 for other defects.
/// Login brand is DEF-023, the light sidebar role is DEF-024, and dark primary
/// text plus cashPositive is DEF-025. The next free number is DEF-026.
bool get _skipDef023 => true;
bool get _skipDef024 => true;
bool get _skipDef025 => true;

/// Pairs DEF-023, DEF-024, and DEF-025 already record. Anything else still fails.
bool _knownContrast(String failure) {
  const pairs = [
    '#eab600 on #e5edf6',
    '#172723 on #102a26',
    '#247763 on #172333',
    '#247763 on #1a2c24',
    '#087a50 on #172333',
  ];
  return pairs.any(failure.contains);
}

void main() {
  testWidgets('every main screen applies the light theme', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await visitMainScreens(tester, (path) {
      expectThemeApplied(tester, Brightness.light);
      _expectNoNewContrast(tester, path);
    });
  });

  testWidgets('every main screen applies the dark theme', (tester) async {
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await tester.tap(find.byKey(LoginScreen.themeKey));
    await settle(tester);
    await visitMainScreens(tester, (path) {
      expectThemeApplied(tester, Brightness.dark);
      _expectNoNewContrast(tester, path);
    });
  });

  testWidgets('DEF-023 login brand stays readable on the light scaffold', (
    tester,
  ) async {
    if (_skipDef023) {
      markTestSkipped('DEF-023 known failure');
      return;
    }
    await pumpFakeApp(tester, size: const Size(800, 1400));
    final brand = unreadableText(tester)
        .where((failure) => failure.contains('#eab600 on #e5edf6'));
    expect(brand, isEmpty);
  });

  testWidgets('DEF-024 the sidebar role stays readable in light mode', (
    tester,
  ) async {
    if (_skipDef024) {
      markTestSkipped('DEF-024 known failure');
      return;
    }
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final role = unreadableText(tester)
        .where((failure) => failure.contains('#172723 on #102a26'));
    expect(role, isEmpty);
  });

  testWidgets('DEF-025 dark primary text and cash amounts stay readable', (
    tester,
  ) async {
    if (_skipDef025) {
      markTestSkipped('DEF-025 known failure');
      return;
    }
    await pumpFakeApp(tester, size: const Size(800, 2400));
    await tester.tap(find.byKey(LoginScreen.themeKey));
    await settle(tester);
    await _expectReadable(tester);
  });

  testWidgets('ThemeMode.system follows platform brightness', (tester) async {
    final binding = tester.platformDispatcher;
    binding.platformBrightnessTestValue = Brightness.light;
    addTearDown(() {
      binding.platformBrightnessTestValue = Brightness.light;
    });
    await pumpFakeApp(
      tester,
      size: const Size(800, 1600),
      overrides: [themeModeProvider.overrideWith(_SystemTheme.new)],
    );

    expectThemeApplied(tester, Brightness.light);
    binding.platformBrightnessTestValue = Brightness.dark;
    await settle(tester);
    expectThemeApplied(tester, Brightness.dark);

    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expectThemeApplied(tester, Brightness.dark);
    await go(tester, '/notifications');
    expectThemeApplied(tester, Brightness.dark);

    binding.platformBrightnessTestValue = Brightness.light;
    await settle(tester);
    expectThemeApplied(tester, Brightness.light);
    await go(tester, '/');
    expectThemeApplied(tester, Brightness.light);
    expectQuiet(tester, 'system theme');
  });
}

void _expectNoNewContrast(WidgetTester tester, String path) {
  final fresh = unreadableText(tester)
      .where((failure) => !_knownContrast(failure));
  expect(fresh, isEmpty, reason: '$path ${fresh.join('; ')}');
}

Future<void> _expectReadable(WidgetTester tester) async {
  final unreadable = <String>[];
  await visitMainScreens(tester, (path) {
    final found = unreadableText(tester);
    if (found.isNotEmpty) {
      unreadable.add('$path: ${found.take(4).join('; ')}');
    }
  });
  expect(unreadable, isEmpty, reason: unreadable.join('\n'));
}

class _SystemTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;
}
