import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/splash/splash_screen.dart';
import 'package:vib_abdo_company_mobile/state/session_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save light and dark shots at 360 and 430', (tester) async {
    await pumpFakeApp(
      tester,
      size: const Size(360, 900),
      overrides: [
        startupProvider.overrideWith((ref) async {
          throw StateError('startup failed');
        }),
      ],
    );
    await tester.runAsync(loadScreenshotFonts);
    await tester.pump();
    expect(find.byKey(SplashScreen.retryKey), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    await saveShot(tester, 'splash-error-light-360');

    const emptyStates = <String, (String, String)>{
      '/settings/employees': ('settings-employees', AppStrings.employeesEmpty),
      '/settings/audit': ('settings-audit', AppStrings.auditEmpty),
      '/settings/operations': (
        'settings-operations',
        AppStrings.operationsEmpty,
      ),
    };
    for (final dark in [false, true]) {
      for (final width in [360.0, 430.0]) {
        final theme = dark ? 'dark' : 'light';
        final suffix = '$theme-${width.toInt()}';
        await pumpFakeApp(tester, size: Size(width, 900));
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await settle(tester);
        }
        await saveShot(tester, 'login-$suffix');
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        await saveShot(tester, 'home-$suffix');

        await go(tester, '/settings');
        expect(find.text(AppStrings.employeesTile), findsOneWidget);
        await saveShot(tester, 'settings-$suffix');
        for (final entry in emptyStates.entries) {
          await go(tester, entry.key);
          expect(find.text(entry.value.$2), findsOneWidget);
          expect(find.text(AppStrings.unavailable), findsNothing);
          await saveShot(tester, '${entry.value.$1}-$suffix');
        }

        await go(tester, '/notifications');
        await saveShot(tester, 'notifications-$suffix');

        await go(tester, '/');
        await tester.ensureVisible(find.byKey(const Key('bottom-tab-more')));
        await tester.tap(find.byKey(const Key('bottom-tab-more')));
        await settle(tester);
        expect(find.byKey(const Key('more-sheet')), findsOneWidget);
        await saveShot(tester, 'more-$suffix');

        final layer = await pumpFakeApp(tester, size: Size(width, 900));
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await settle(tester);
        }
        (layer.client as FakeApiClient).failHomeRemaining = 8;
        await signIn(tester, username: 'employee.demo', password: 'demo-only');
        expect(find.byKey(const Key('home-fallback-banner')), findsOneWidget);
        await saveShot(tester, 'home-fallback-$suffix');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> saveBoundaryShot(
  WidgetTester tester,
  Finder finder,
  String name,
) async {
  RenderRepaintBoundary? boundary;
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    boundary = tester.renderObject<RenderRepaintBoundary>(finder);
    if (!boundary.debugNeedsPaint) break;
  }
  expect(boundary!.debugNeedsPaint, isFalse, reason: 'boundary still dirty');
  // toImage asserts the layer is painted. A later await lets a spinner schedule
  // another frame and mark the boundary dirty before the assert runs.
  final imageFuture = boundary.toImage(pixelRatio: 1);
  final captured = await tester.runAsync(() async {
    final image = await imageFuture;
    final width = image.width;
    final height = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return (width, height, data!.buffer.asUint8List());
  });
  expect(captured, isNotNull, reason: 'no pixels for $name');
  final png = _pngFromRgba(captured!.$3, captured.$1, captured.$2);
  expect(png.length, greaterThan(500), reason: name);
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png').writeAsBytesSync(png);
  try {
    Directory('/opt/cursor/artifacts/screenshots').createSync(recursive: true);
    File('/opt/cursor/artifacts/screenshots/$name.png').writeAsBytesSync(png);
  } on FileSystemException {
    // The artifact directory exists for this agent, not in CI.
  }
}

Future<void> saveShot(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  RenderRepaintBoundary? match;
  RenderRepaintBoundary? best;
  var bestArea = 0.0;
  for (final element in find.byType(RepaintBoundary).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderRepaintBoundary ||
        !render.hasSize ||
        !render.attached) {
      continue;
    }
    final area = render.size.width * render.size.height;
    if (area > bestArea) {
      bestArea = area;
      best = render;
    }
    final close =
        (render.size.width - view.width).abs() < 2 &&
        (render.size.height - view.height).abs() < 2;
    if (close) match = render;
  }
  final boundary = match ?? best;
  expect(boundary, isNotNull, reason: 'no boundary for $name');
  final captured = await tester.runAsync(() async {
    final image = await boundary!.toImage(pixelRatio: 1);
    final width = image.width;
    final height = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return (width, height, data!.buffer.asUint8List());
  });
  expect(captured, isNotNull, reason: 'no pixels for $name');
  final png = _pngFromRgba(captured!.$3, captured.$1, captured.$2);
  expect(png.length, greaterThan(500), reason: name);
  // Sync writes: async file IO does not finish while the test binding is idle.
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png').writeAsBytesSync(png);
  try {
    Directory('/opt/cursor/artifacts/screenshots').createSync(recursive: true);
    File('/opt/cursor/artifacts/screenshots/$name.png').writeAsBytesSync(png);
  } on FileSystemException {
    // The artifact directory exists for this agent, not in CI.
  }
}

/// `Image.toByteData(png)` does not complete under flutter_tester.
Uint8List _pngFromRgba(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder(copy: false);
  final stride = width * 4;
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * stride, (y + 1) * stride));
  }
  final compressed = ZLibEncoder(level: 1).convert(raw.takeBytes());
  final out = BytesBuilder(copy: false);
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  _pngChunk(out, 'IHDR', _pngIhdr(width, height));
  _pngChunk(out, 'IDAT', compressed);
  _pngChunk(out, 'IEND', const []);
  return out.takeBytes();
}

void _pngChunk(BytesBuilder out, String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final length = ByteData(4)..setUint32(0, data.length);
  out.add(length.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);
  final crc = _pngCrc([...typeBytes, ...data]);
  final crcBytes = ByteData(4)..setUint32(0, crc);
  out.add(crcBytes.buffer.asUint8List());
}

Uint8List _pngIhdr(int width, int height) {
  final data = ByteData(13);
  data.setUint32(0, width);
  data.setUint32(4, height);
  data.setUint8(8, 8);
  data.setUint8(9, 6);
  return data.buffer.asUint8List();
}

int _pngCrc(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xEDB88320 & mask);
    }
  }
  return crc ^ 0xFFFFFFFF;
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
