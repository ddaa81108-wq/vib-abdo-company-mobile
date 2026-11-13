import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/search/search_screen.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;
import 'support/phase7_nav.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('075 unified search at 360', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFakeApp(tester, size: const Size(360, 800));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/search');

    await tester.enterText(
      find.byKey(const Key('unified-search')),
      'عميل تجريبي',
    );
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix075-suggestions-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix075-suggestions-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('unified-search')), 'zzzz');
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix075-empty-light-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix075-empty-dark-360');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified-search')),
      'عميل تجريبي',
    );
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-hit-customers-c_55')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix075-opened-light-360');

    await go(tester, '/search');
    await tester.tap(find.byKey(const Key('app-bar-theme')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('unified-search')),
      'عميل تجريبي',
    );
    await tester.pump(SearchScreen.debounce);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-hit-customers-c_55')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix075-opened-dark-360');
  }, tags: ['screenshots']);
}
