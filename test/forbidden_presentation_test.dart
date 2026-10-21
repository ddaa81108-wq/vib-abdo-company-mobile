import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vib_abdo_company_mobile/error_handling/app_failure.dart';
import 'package:vib_abdo_company_mobile/features/forbidden/forbidden_screen.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/features/settings/settings_screen.dart';
import 'package:vib_abdo_company_mobile/state/section_providers.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';
import 'package:vib_abdo_company_mobile/ui/theme.dart';
import 'package:vib_abdo_company_mobile/ui/widgets/common.dart';

import 'support/pump_app.dart';

const _captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');

void main() {
  testWidgets('employee hides management totals, decisions, and admin tiles', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(360, 900));
    await signIn(tester, username: 'employee.demo', password: 'demo-only');
    expectRtl(tester);

    expect(find.text(AppStrings.settings), findsNothing);
    expect(find.text(AppStrings.employeesTile), findsNothing);
    expect(find.text(AppStrings.employeeTotals), findsNothing);
    expect(find.byKey(const Key('collections-metrics')), findsNothing);
    expect(find.byKey(const Key('financial-ledger')), findsNothing);
    for (final action in [
      ManagementAction.collectionsDecide,
      ManagementAction.settingsManage,
    ]) {
      expect(find.byKey(HomeShell.actionKey(action)), findsNothing);
    }

    await go(tester, '/collections');
    expect(find.text(AppStrings.employeeTotals), findsNothing);
    expect(find.byKey(const Key('collections-metrics')), findsNothing);
    expect(find.text(AppStrings.approve), findsNothing);
    expect(find.text(AppStrings.reject), findsNothing);
    expect(find.byKey(const Key('approve-sb_1')), findsNothing);
    expect(find.byKey(const Key('reject-sb_1')), findsNothing);
    expect(tester.takeException(), isNull);

    await go(tester, '/settings/employees');
    expect(find.byKey(const Key('screen-settings-employees')), findsNothing);
    expect(find.text(AppStrings.employeesEmpty), findsNothing);
    expect(find.byKey(ForbiddenScreen.screenKey), findsOneWidget);
    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin still sees totals, approve, reject, and admin tiles', (
    tester,
  ) async {
    await pumpFakeApp(tester, size: const Size(800, 1600));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    expect(
      find.byKey(HomeShell.actionKey(ManagementAction.collectionsDecide)),
      findsOneWidget,
    );
    expect(
      find.byKey(HomeShell.actionKey(ManagementAction.settingsManage)),
      findsOneWidget,
    );

    await go(tester, '/collections');
    expect(find.byKey(const Key('collections-metrics')), findsOneWidget);
    expect(find.text(AppStrings.employeeTotals), findsOneWidget);
    expect(find.byKey(const Key('approve-sb_1')), findsOneWidget);
    expect(find.byKey(const Key('reject-sb_1')), findsOneWidget);

    await go(tester, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(AppStrings.employeesTile), findsOneWidget);
    expect(find.byKey(const Key('financial-ledger')), findsOneWidget);
    expect(find.text(AppStrings.pageTotals), findsOneWidget);
  });

  testWidgets('a 403 load shows the forbidden pane, not the raw server text', (
    tester,
  ) async {
    const raw = 'هذا الإجراء للإدارة فقط';
    await pumpFakeApp(
      tester,
      size: const Size(320, 568),
      overrides: [
        accountsProvider.overrideWith((ref, section) async {
          throw const ForbiddenException(
            code: 'FORBIDDEN',
            message: raw,
            statusCode: 403,
          );
        }),
      ],
    );
    await signIn(tester, username: 'admin.demo', password: 'demo-only');
    await go(tester, '/customers');

    expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsOneWidget);
    expect(find.text(raw), findsNothing);
    expect(find.text(AppStrings.retry), findsNothing);
    expectRtl(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forbidden pane fits a small phone in light and dark', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await _pumpPane(tester, dark: dark, size: const Size(320, 568));
      expect(find.byKey(ForbiddenPane.paneKey), findsOneWidget);
      expect(find.text(AppStrings.forbidden), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expectRtl(tester);
      expect(
        Theme.of(tester.element(find.byKey(ForbiddenPane.paneKey))).brightness,
        dark ? Brightness.dark : Brightness.light,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('repeated 403 snackbars collapse to one unified notice', (
    tester,
  ) async {
    const raw = 'raw server sentence';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                const failure = AppFailure(message: raw, code: 'FORBIDDEN');
                showFailureSnackBar(context, failure);
                showFailureSnackBar(context, failure);
              },
              child: const Text('send'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('send'));
    await tester.pump();
    expect(find.byKey(const Key('forbidden-snackbar')), findsOneWidget);
    expect(find.text(AppStrings.forbidden), findsOneWidget);
    expect(find.text(raw), findsNothing);
  });

  testWidgets(
    'screenshots of the forbidden pane on a small phone',
    (tester) async {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        await _pumpPane(tester, dark: dark, size: const Size(320, 568));
        await tester.runAsync(loadScreenshotFonts);
        await tester.pump();
        await saveShot(tester, 'forbidden-pane-$theme-320');
      }
    },
    skip: !_captureScreenshots,
    tags: const ['screenshots'],
  );
}

Future<void> _pumpPane(
  WidgetTester tester, {
  required bool dark,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: ForbiddenPane()),
    ),
  );
  await tester.pump();
}

void expectRtl(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  expect(Directionality.of(context), TextDirection.rtl);
}

Future<void> go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> loadScreenshotFonts() async {
  final cairo = File('assets/fonts/Cairo-Variable.ttf');
  if (cairo.existsSync()) {
    await ui.loadFontFromList(await cairo.readAsBytes(), fontFamily: 'Cairo');
  }
  final icons = File(Platform.resolvedExecutable).parent.parent.parent;
  final material = File(
    '${icons.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  if (material.existsSync()) {
    await ui.loadFontFromList(
      await material.readAsBytes(),
      fontFamily: 'MaterialIcons',
    );
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
  Directory('build/screenshots').createSync(recursive: true);
  File('build/screenshots/$name.png').writeAsBytesSync(png);
  try {
    Directory('/opt/cursor/artifacts/screenshots').createSync(recursive: true);
    File('/opt/cursor/artifacts/screenshots/$name.png').writeAsBytesSync(png);
  } on FileSystemException {
    // Artifact directory is present for this agent, not in CI.
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
