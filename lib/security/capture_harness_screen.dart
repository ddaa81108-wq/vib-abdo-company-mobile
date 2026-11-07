import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../ui/theme.dart';

/// Drawn content and session buttons for an ephemeral capture check.
/// Release builds import [capture_harness_screen_stub.dart] instead, so these
/// fixture identities are not linked into a release APK.
class CaptureHarnessScreen extends ConsumerWidget {
  const CaptureHarnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(apiLayerProvider).session;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              key: const Key('capture-harness-mark'),
              height: 120,
              alignment: Alignment.center,
              color: const Color(0xFFF5C02E),
              child: Text(
                'محتوى ظاهر',
                style: cairo(28, 800, color: const Color(0xFF1A1300)),
              ),
            ),
            const SizedBox(height: 12),
            _button('دخول مدير', () => session.login(
              username: 'admin.demo',
              password: 'demo-only',
            )),
            _button('دخول موظف', () => session.login(
              username: 'employee.demo',
              password: 'demo-only',
            )),
            _button('دخول ضيف', () => session.login(
              username: 'guest',
              password: 'demo-only',
            )),
            _button('دخول تحقق', () => session.login(
              username: 'mfa.admin',
              password: 'demo-only',
            )),
            _button('خروج', session.logout),
            _button(
              'انتهاء الجلسة',
              () => session.forceLogout('session_expired'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, Future<void> Function() onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton(
        onPressed: () => onPressed(),
        child: Text(label),
      ),
    );
  }
}
