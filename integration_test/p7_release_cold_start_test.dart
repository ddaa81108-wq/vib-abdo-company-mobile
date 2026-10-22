import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vib_abdo_company_mobile/main.dart' as app;
import 'package:vib_abdo_company_mobile/performance/perf_budget.dart';
import 'package:vib_abdo_company_mobile/performance/perf_surface.dart';

import '../test/support/pump_app.dart';

/// P7-23. Release, real mode, until the home screen.
///
/// A host run, and any run with the fake API, records a skip. That is not a
/// cold start and it is not an acceptance Pass. Ali writes the threshold.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P7-23 release cold start until interactive home', (
    tester,
  ) async {
    const useFake = bool.fromEnvironment('USE_FAKE_API', defaultValue: true);
    final surface = currentPerfSurface();
    phase7('p7_23_surface', surface.name);
    phase7('p7_23_use_fake_api', useFake);

    if (surface == PerfSurface.host || useFake) {
      phase7('p7_23', 'skipped');
      phase7('p7_23_reason', 'release-protocol-not-this-surface');
      phase7('p7_23_acceptance', 'recorded');
      return;
    }

    const base = String.fromEnvironment('API_BASE');
    const username = String.fromEnvironment('STAGING_ADMIN_USERNAME');
    const password = String.fromEnvironment('STAGING_ADMIN_PASSWORD');
    if (base.isEmpty || username.isEmpty || password.isEmpty) {
      fail(
        'P7-23 needs API_BASE, STAGING_ADMIN_USERNAME, and '
        'STAGING_ADMIN_PASSWORD. The names are unset. Values are not printed.',
      );
    }

    final watch = Stopwatch()..start();
    app.main();
    await _until(tester, const Key('login-screen'));
    final loginMs = watch.elapsedMilliseconds;
    phase7('p7_23_login_screen_ms', loginMs);

    await signIn(tester, username: username, password: password);
    await _until(tester, const Key('home-dashboard'));
    watch.stop();
    final homeMs = watch.elapsedMilliseconds;
    phase7('p7_23_home_ms', homeMs);
    phase7('p7_23_acceptance', 'recorded');

    if (homeMs > PerfBudget.stagingHomeHangMs) {
      fail(
        'P7-23 home took ${homeMs}ms, past the ${PerfBudget.stagingHomeHangMs}ms hang ceiling',
      );
    }
  });
}

void phase7(String key, Object value) {
  // ignore: avoid_print
  print('PHASE7 $key=$value');
}

Future<void> _until(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  for (var i = 0; i < 80; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('missing $key');
}
