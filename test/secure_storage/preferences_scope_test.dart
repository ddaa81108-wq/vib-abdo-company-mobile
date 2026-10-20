import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vib_abdo_company_mobile/state/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shared preferences store only the theme name', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.light);
    await container.read(themeModeProvider.notifier).setDark(true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'app-theme'});
    expect(prefs.getString('app-theme'), 'dark');

    await container.read(themeModeProvider.notifier).setDark(false);
    expect(prefs.getString('app-theme'), 'light');
    expect(prefs.getKeys(), {'app-theme'});
  });
}
