import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vib_abdo_company_mobile/api/api_providers.dart';
import 'package:vib_abdo_company_mobile/app.dart';
import 'package:vib_abdo_company_mobile/features/home/home_shell.dart';
import 'package:vib_abdo_company_mobile/notifications/background_scheduler.dart';
import 'package:vib_abdo_company_mobile/notifications/push_providers.dart';
import 'package:vib_abdo_company_mobile/notifications/shown_notification_store.dart';
import 'package:vib_abdo_company_mobile/state/connectivity.dart';
import 'package:vib_abdo_company_mobile/ui/strings.dart';

import 'support/pump_app.dart';

const _shot = Key('shot');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outputDir;

  setUpAll(() async {
    final preferred = Directory(
      Platform.environment['SCREENSHOT_DIR'] ??
          '/opt/cursor/artifacts/screenshots',
    );
    // Real file I/O does not complete inside a widget test's fake async zone.
    // CI may not have the artifact directory, so fall back to a temp folder.
    try {
      await preferred.create(recursive: true);
      outputDir = preferred;
    } on FileSystemException {
      outputDir = await Directory.systemTemp.createTemp(
        'treasury-reports-shots',
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('captures treasury and reports in light and dark', (
    tester,
  ) async {
    const height = 1400.0;
    await _pump(tester, const Size(360, height));
    await signIn(tester, username: 'admin.demo', password: 'demo-only');

    for (final width in const [360.0, 430.0]) {
      await _resize(tester, Size(width, height));
      await _go(tester, '/treasury');
      await _shoot(tester, outputDir, 'treasury-light-${width.toInt()}');
      await _go(tester, '/reports');
      await _shoot(tester, outputDir, 'reports-light-${width.toInt()}');
    }

    await _resize(tester, const Size(800, height));
    await tester.tap(find.byTooltip(AppStrings.themeDark));
    await _settle(tester);
    for (final width in const [360.0, 430.0]) {
      await _resize(tester, Size(width, height));
      await _go(tester, '/treasury');
      await _shoot(tester, outputDir, 'treasury-dark-${width.toInt()}');
      await _go(tester, '/reports');
      await _shoot(tester, outputDir, 'reports-dark-${width.toInt()}');
    }
  });
}

Future<void> _loadFonts() async {
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
  // flutter_tester is bin/cache/artifacts/engine/<arch>/flutter_tester.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final candidate = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  );
  if (candidate.existsSync()) return candidate;
  return null;
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final layer = ApiLayer.create(
    config: const ApiConfig(baseUrl: 'https://fake.invalid', useFakeApi: true),
    fakeLatency: Duration.zero,
  );
  addTearDown(layer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        apiLayerProvider.overrideWithValue(layer),
        connectivityPortProvider.overrideWithValue(
          const FixedConnectivity(true),
        ),
        backgroundNotificationSchedulerProvider.overrideWithValue(
          const NoopBackgroundNotificationScheduler(),
        ),
        shownNotificationStoreProvider.overrideWithValue(
          MemoryShownNotificationStore(),
        ),
      ],
      child: const RepaintBoundary(key: _shot, child: CompanyApp()),
    ),
  );
  await _settle(tester);
  // FontLoader before the app starts leaves icons as empty squares.
  // Load the real faces once the test app is up, then paint again.
  await tester.runAsync(_loadFonts);
  await tester.pump();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await _settle(tester);
}

Future<void> _go(WidgetTester tester, String path) async {
  final context = tester.element(find.byKey(HomeShell.shellKey));
  GoRouter.of(context).go(path);
  await _settle(tester);
}

Future<void> _shoot(WidgetTester tester, Directory dir, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shot),
  );
  // toImage waits on the raster thread. toImageSync returns a handle now.
  final image = boundary.toImageSync(pixelRatio: 2);
  final length = await tester.runAsync(() async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(bytes, flush: true);
      return bytes.length;
    } finally {
      image.dispose();
    }
  });
  expect(length, greaterThan(1000));
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}
