import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/features/settings/admin_destinations.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

/// Headless `flutter test` does not paint `toImage` reliably. The capture
/// stays tagged `screenshots` and is skipped unless this define is set.
const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

void main() {
  testWidgets('the financial ledger tile shows the server totals', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pumpFakeApp(tester, size: const Size(360, 1200));
      if (dark) await _dark(tester);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      await go(tester, '/settings');

      expect(find.byKey(const Key('financial-ledger')), findsOneWidget);
      expect(find.text(AppStrings.financialLedger), findsOneWidget);
      expect(find.text(AppStrings.pageTotals), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('ledger-total-LYD'))).data,
        '0 د.ل',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('ledger-total-EGP'))).data,
        '0 ج.م',
      );
      expect(find.textContaining('LYD'), findsNothing);
      expect(find.textContaining('EGP'), findsNothing);
      expect(find.text(AppStrings.emptyLedger), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byKey(const Key('financial-ledger'))),
        ).brightness,
        dark ? Brightness.dark : Brightness.light,
      );
      for (final destination in adminDestinations) {
        expect(find.byKey(destination.tileKey), findsOneWidget);
      }
    }
  });

  testWidgets('employees, audit, and operations use an empty pane', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pumpFakeApp(tester, size: const Size(360, 1000));
      if (dark) await _dark(tester);
      await signIn(tester, username: 'admin.demo', password: 'demo-only');
      for (final destination in adminDestinations) {
        await go(tester, destination.path);
        final pane = find.byType(EmptyPane);
        expect(pane, findsOneWidget);
        expect(find.byKey(destination.screenKey), findsOneWidget);
        expect(
          find.descendant(of: pane, matching: find.text(destination.title)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: pane,
            matching: find.text(destination.emptyMessage),
          ),
          findsOneWidget,
        );
        final icon = tester.widget<Icon>(
          find.descendant(of: pane, matching: find.byIcon(destination.icon)),
        );
        final theme = Theme.of(tester.element(pane));
        expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
        expect(icon.color, theme.colorScheme.onSurfaceVariant);
        expect(find.text(AppStrings.unavailable), findsNothing);
        expect(find.textContaining('لا تتوفر بيانات من الخادم'), findsNothing);
      }
    }
  });

  testWidgets('admin tiles stay hidden without settings.manage', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'limited.admin.demo', password: 'demo-only');
    await go(tester, '/settings');
    expect(find.byKey(const Key('screen-settings')), findsNothing);
    for (final destination in adminDestinations) {
      expect(find.byKey(destination.tileKey), findsNothing);
      await go(tester, destination.path);
      expect(find.byKey(destination.screenKey), findsNothing);
      expect(find.text(destination.emptyMessage), findsNothing);
    }

    final layer = await pumpFakeApp(tester, size: const Size(360, 1000));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    layer.permissions.applyFromServer(
      const ['settings.manage'],
      role: 'admin',
      sectionAccess: const {},
    );
    await tester.pump();
    await go(tester, '/settings');
    expect(find.byKey(const Key('financial-ledger')), findsNothing);
    for (final destination in adminDestinations) {
      expect(find.byKey(destination.tileKey), findsOneWidget);
    }
  });

  testWidgets(
    'screenshots of admin settings in light and dark at 360 and 430',
    (tester) async {
      for (final dark in [false, true]) {
        for (final width in [360.0, 430.0]) {
          final theme = dark ? 'dark' : 'light';
          final suffix = '$theme-${width.toInt()}';
          await pumpFakeApp(tester, size: Size(width, 900));
          await tester.runAsync(loadScreenshotFonts);
          await tester.pump();
          if (dark) await _dark(tester);
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await go(tester, '/settings');
          expect(find.byKey(const Key('ledger-total-LYD')), findsOneWidget);
          await saveShot(tester, 'admin-settings-$suffix');
          await tester.ensureVisible(find.byKey(const Key('ledger-total-LYD')));
          await tester.pump();
          await saveShot(tester, 'admin-ledger-$suffix');
          for (final destination in adminDestinations) {
            await go(tester, destination.path);
            expect(find.text(destination.emptyMessage), findsOneWidget);
            await saveShot(tester, 'admin-${destination.id}-$suffix');
          }
        }
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
  );
}

Future<void> _dark(WidgetTester tester) async {
  await tester.tap(find.byKey(LoginScreen.themeKey));
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
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png').writeAsBytesSync(png);
  try {
    Directory('/opt/cursor/artifacts/screenshots').createSync(recursive: true);
    File(
      '/opt/cursor/artifacts/screenshots/$name.png',
    ).writeAsBytesSync(png);
  } on FileSystemException {
    // The artifact directory exists for this agent, not in CI.
  }
}

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
