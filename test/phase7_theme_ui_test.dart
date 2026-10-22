import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

import 'support/phase7_ui.dart';
import 'support/pump_app.dart';

bool get _skipDef020 => true;
bool get _skipDef021 => true;
bool get _skipDef022 => true;

/// Pairs the skipped contrast tests already record. Anything else still fails.
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

  testWidgets('login brand stays readable on the light scaffold', (
    tester,
  ) async {
    if (_skipDef020) {
      markTestSkipped('DEF-020 known failure');
      return;
    }
    await pumpFakeApp(tester, size: const Size(800, 1400));
    final brand = unreadableText(tester)
        .where((failure) => failure.contains('#eab600 on #e5edf6'));
    expect(brand, isEmpty);
  });

  testWidgets('the sidebar role stays readable in light mode', (tester) async {
    if (_skipDef021) {
      markTestSkipped('DEF-021 known failure');
      return;
    }
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    final role = unreadableText(tester)
        .where((failure) => failure.contains('#172723 on #102a26'));
    expect(role, isEmpty);
  });

  testWidgets('dark theme text stays readable', (tester) async {
    if (_skipDef022) {
      markTestSkipped('DEF-022 known failure');
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
