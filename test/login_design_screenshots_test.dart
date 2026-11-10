import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_design_options.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;

void main() {
  testWidgets('preview four login designs', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    for (final dark in [false, true]) {
      for (final option in [1, 2, 3, 4]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
            home: Scaffold(body: LoginDesignOption(option: option)),
          ),
        );
        await tester.pump();
        await saveShot(
          tester,
          'login-design-$option-${dark ? 'dark' : 'light'}',
        );
      }
    }
  }, tags: const ['screenshots']);
}
