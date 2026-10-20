import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/change_password_screen.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/login/signup_info_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save light and dark shots at 360 and 430', (tester) async {
    const screens = <String, String>{
      '/': 'home',
      '/settings': 'settings',
      '/settings/employees': 'settings-employees',
      '/settings/audit': 'settings-audit',
      '/settings/operations': 'settings-operations',
      '/account': 'account',
      '/notifications': 'notifications',
    };
    for (final dark in [false, true]) {
      for (final width in [360.0, 430.0]) {
        final theme = dark ? 'dark' : 'light';
        await pumpFakeApp(tester, size: Size(width, 900));
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await settle(tester);
        }
        await saveShot(tester, 'login-$theme-${width.toInt()}');
        await goFrom(tester, find.byKey(LoginScreen.screenKey), '/signup-info');
        expect(find.byKey(SignupInfoScreen.screenKey), findsOneWidget);
        await saveShot(tester, 'signup-info-$theme-${width.toInt()}');
        await goFrom(tester, find.byKey(SignupInfoScreen.screenKey), '/login');
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        for (final entry in screens.entries) {
          await go(tester, entry.key);
          await saveShot(tester, '${entry.value}-$theme-${width.toInt()}');
        }
        if (width == 360) {
          await go(tester, '/');
          await tester.tap(find.byKey(HomeShell.menuKey));
          await settle(tester);
          await saveShot(tester, 'drawer-$theme-360');
          Navigator.of(tester.element(find.byType(Drawer))).pop();
          await settle(tester);
          await tester.ensureVisible(find.byKey(const Key('bottom-tab-more')));
          await tester.tap(find.byKey(const Key('bottom-tab-more')));
          await settle(tester);
          await saveShot(tester, 'more-$theme-360');
          Navigator.of(tester.element(find.byKey(const Key('more-sheet'))))
              .pop();
          await settle(tester);
        }
        await go(tester, '/account/password');
        expect(find.byKey(ChangePasswordScreen.screenKey), findsOneWidget);
        await saveShot(tester, 'change-password-$theme-${width.toInt()}');
      }
    }

    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';
      await pumpFakeApp(tester, size: const Size(800, 1000));
      await tester.runAsync(loadScreenshotFonts);
      await tester.pump();
      if (dark) {
        await tester.tap(find.byKey(LoginScreen.themeKey));
        await settle(tester);
      }
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.byKey(HomeShell.railKey), findsOneWidget);
      await saveShot(tester, 'rail-$theme-800');

      await pumpFakeApp(tester, size: const Size(1100, 1000));
      await tester.runAsync(loadScreenshotFonts);
      await tester.pump();
      if (dark) {
        await tester.tap(find.byKey(LoginScreen.themeKey));
        await settle(tester);
      }
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      expect(find.byKey(HomeShell.panelKey), findsOneWidget);
      expect(find.text(AppStrings.organization), findsOneWidget);
      await saveShot(tester, 'panel-$theme-1100');
    }
  });
}

Future<void> saveShot(WidgetTester tester, String name) async {
  await tester.pump();
  RenderRepaintBoundary? best;
  var bestArea = 0.0;
  for (final element in find.byType(RepaintBoundary).evaluate()) {
    final render = element.renderObject;
    if (render is RenderRepaintBoundary && render.hasSize && render.attached) {
      final area = render.size.width * render.size.height;
      if (area > bestArea) {
        bestArea = area;
        best = render;
      }
    }
  }
  expect(best, isNotNull, reason: 'no boundary for $name');
  final boundary = best!;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  expect(image, isNotNull, reason: 'no image for $name');
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  expect(data, isNotNull, reason: 'no bytes for $name');
  final bytes = data!.buffer.asUint8List();
  expect(bytes.length, greaterThan(500), reason: name);
  final dir = Directory('build/screenshots');
  await dir.create(recursive: true);
  await File('${dir.path}/$name.png').writeAsBytes(bytes, flush: true);
  final artifact = File('/opt/cursor/artifacts/screenshots/$name.png');
  try {
    await artifact.parent.create(recursive: true);
    await artifact.writeAsBytes(bytes, flush: true);
  } on FileSystemException {
    // The artifact directory exists for this agent, not in CI.
  }
}

Future<void> loadScreenshotFonts() async {
  await _loadFont('assets/fonts/Cairo-Variable.ttf', 'Cairo');
  await _loadFont('assets/fonts/JetBrainsMono-Bold.ttf', 'JetBrainsMono');
  await _loadFont('assets/fonts/JetBrainsMono-ExtraBold.ttf', 'JetBrainsMono');
  final icons = _materialIconsFile();
  if (icons != null) {
    await ui.loadFontFromList(
      await icons.readAsBytes(),
      fontFamily: 'MaterialIcons',
    );
  }
}

Future<void> _loadFont(String path, String family) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await ui.loadFontFromList(await file.readAsBytes(), fontFamily: family);
}

File? _materialIconsFile() {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final candidate = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  if (candidate.existsSync()) return candidate;
  return null;
}

Future<void> goFrom(WidgetTester tester, Finder anchor, String path) async {
  final context = tester.element(anchor);
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
