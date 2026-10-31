import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/login/login_screen.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/environment_badge.dart';

import 'shell_screenshots_test.dart' show go, loadScreenshotFonts;
import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

/// Refresh with:
///   flutter test --dart-define=CAPTURE_SCREENSHOTS=true \
///     --tags screenshots test/env_badge_screenshots_test.dart
/// PNGs land in build/screenshots/env-badge-*.png.
void main() {
  testWidgets(
    'env badge screenshots: fake and staging, light and dark, 320x568 and '
    '430x932, plus an http production warning',
    (tester) async {
      final staging = resolveBuildEnvironment(
        useFakeApi: false,
        apiBase: 'https://staging.vip2100.com',
      );
      final insecure = resolveBuildEnvironment(
        useFakeApi: false,
        apiBase: 'http://vip2100.com',
      );
      Future<void> open(Size size, bool dark, BuildEnvironment? env) async {
        await pumpFakeApp(tester, size: size, environment: env);
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        if (dark) {
          await tester.tap(find.byKey(LoginScreen.themeKey));
          await tester.pumpAndSettle();
        }
      }

      for (final dark in [false, true]) {
        for (final size in const [Size(320, 568), Size(430, 932)]) {
          final suffix =
              '${dark ? 'dark' : 'light'}-${size.width.toInt()}x${size.height.toInt()}';
          await open(size, dark, null);
          expect(find.text(AppStrings.envFake), findsOneWidget);
          await _saveRootShot(tester, 'env-badge-fake-login-$suffix');
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await _saveRootShot(tester, 'env-badge-fake-home-$suffix');
          await go(tester, '/settings');
          await _saveRootShot(tester, 'env-badge-fake-settings-$suffix');

          await open(size, dark, staging);
          expect(find.text(AppStrings.envStaging), findsOneWidget);
          await _saveRootShot(tester, 'env-badge-staging-login-$suffix');
          await signIn(tester, username: 'admin.demo', password: 'demo-only');
          await _saveRootShot(tester, 'env-badge-staging-home-$suffix');
        }
      }
      for (final dark in [false, true]) {
        await open(const Size(320, 568), dark, insecure);
        await signIn(tester, username: 'admin.demo', password: 'demo-only');
        expect(
          find.text(AppStrings.envProductionMismatch('http://vip2100.com')),
          findsOneWidget,
        );
        await _saveRootShot(
          tester,
          'env-badge-http-production-home-${dark ? 'dark' : 'light'}-320x568',
        );
      }
    },
    tags: const ['screenshots'],
    skip: !_captureScreenshots,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// The shell's `saveShot` paints the route's boundary, which sits below the
/// app-level badge. This paints the whole view, badge included.
Future<void> _saveRootShot(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final captured = await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & size);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = (image.width, image.height, data!.buffer.asUint8List());
    image.dispose();
    return result;
  });
  final png = _png(captured!.$3, captured.$1, captured.$2);
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png').writeAsBytesSync(png);
}

Uint8List _png(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }
  final out = BytesBuilder(copy: false)
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  _chunk(out, 'IHDR', header.buffer.asUint8List());
  _chunk(out, 'IDAT', ZLibEncoder(level: 1).convert(raw.takeBytes()));
  _chunk(out, 'IEND', const []);
  return out.takeBytes();
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  out
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(body)
    ..add((ByteData(4)..setUint32(0, _crc(body))).buffer.asUint8List());
}

int _crc(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
  }
  return crc ^ 0xFFFFFFFF;
}
