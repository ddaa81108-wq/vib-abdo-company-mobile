@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/logout_confirm.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('logout then login shows login and the new home', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    await pumpFakeApp(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);

    await _logout(tester);
    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
    await saveShot(tester, 'fix099-login-after-logout');

    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expect(find.byKey(HomeShell.shellKey), findsOneWidget);
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.collections)),
      findsOneWidget,
    );
    await saveShot(tester, 'fix099-employee-home');

    await _logout(tester);
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(
      find.byKey(HomeShell.sectionKey(SectionKey.purchases)),
      findsOneWidget,
    );
    await saveShot(tester, 'fix099-admin-home');
  });
}

Future<void> _logout(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(HomeShell.logoutKey));
  await tester.tap(find.byKey(HomeShell.logoutKey));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byKey(LogoutConfirmDialog.dialogKey), findsOneWidget);
  await tester.tap(find.byKey(LogoutConfirmDialog.confirmKey));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> saveShot(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
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
    final close =
        (render.size.width - view.width).abs() < 2 &&
        (render.size.height - view.height).abs() < 2;
    if (close || area > bestArea) {
      bestArea = area;
      best = render;
      if (close) break;
    }
  }
  expect(best, isNotNull, reason: name);
  final captured = await tester.runAsync(() async {
    final image = await best!.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final size = (image.width, image.height);
    image.dispose();
    return (size.$1, size.$2, data!.buffer.asUint8List());
  });
  final png = _pngFromRgba(captured!.$3, captured.$1, captured.$2);
  for (final dir in ['/opt/cursor/artifacts/fix099', 'build/screenshots']) {
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(png);
  }
}

Future<void> loadScreenshotFonts() async {
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/IBMPlexSansArabic-$weight.ttf');
    if (!file.existsSync()) continue;
    await ui.loadFontFromList(
      await file.readAsBytes(),
      fontFamily: 'IBMPlexSansArabic',
    );
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
  final crcBytes = ByteData(4)..setUint32(0, _pngCrc([...typeBytes, ...data]));
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
