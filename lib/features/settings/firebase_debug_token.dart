import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/push_providers.dart';
import '../../notifications/push_transport.dart';
import '../../ui/tokens.dart';
import '../notifications/notification_permission.dart';

/// Release builds pass false. Debug builds pass [kDebugMode], which the
/// release compiler removes together with the `if (kDebugMode)` call site.
bool showFirebaseDebugToken({required bool debugBuild}) => debugBuild;

/// Empty in release. The development screen calls this only under `kDebugMode`.
Widget developmentFirebaseSection({required bool includeDebugRow}) {
  if (!showFirebaseDebugToken(debugBuild: includeDebugRow)) {
    return const SizedBox.shrink();
  }
  return const FirebaseDebugTokenPanel();
}

/// Copies the device token. Tests replace this. The token is not logged.
final firebaseTokenCopyProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (token) => Clipboard.setData(ClipboardData(text: token));
});

/// Debug-only Firebase token row. A missing server route must not throw.
class FirebaseDebugTokenPanel extends ConsumerStatefulWidget {
  const FirebaseDebugTokenPanel({super.key});

  static const rowKey = Key('firebase-debug-row');
  static const statusKey = Key('firebase-debug-status');
  static const permissionKey = Key('firebase-debug-permission');
  static const copyKey = Key('firebase-debug-copy');
  static const askKey = Key('firebase-debug-ask');

  @override
  ConsumerState<FirebaseDebugTokenPanel> createState() =>
      _FirebaseDebugTokenPanelState();
}

class _FirebaseDebugTokenPanelState
    extends ConsumerState<FirebaseDebugTokenPanel> {
  var _configured = false;
  var _permission = NotificationPermissionChoice.denied;
  String? _token;
  var _loaded = false;
  var _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final transport = ref.read(pushTransportProvider);
      var configured = false;
      if (transport is FcmPushTransport) {
        await transport.prepare();
        configured = transport.configured;
      }
      final service = ref.read(notificationPermissionServiceProvider);
      var choice = await service.status();
      // Ask even when the device endpoint is missing. The registrar
      // swallows that POST; this screen still needs the system choice.
      if (configured &&
          !_asked &&
          choice == NotificationPermissionChoice.denied) {
        _asked = true;
        choice = await service.request();
      }
      final token = configured ? await transport.currentToken() : null;
      if (!mounted) return;
      setState(() {
        _configured = configured;
        _permission = choice;
        _token = token;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _ask() async {
    try {
      final service = ref.read(notificationPermissionServiceProvider);
      final choice = await service.request();
      if (!mounted) return;
      setState(() => _permission = choice);
      await _load();
    } catch (_) {}
  }

  Future<void> _copy() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await ref.read(firebaseTokenCopyProvider)(token);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final granted = _permission == NotificationPermissionChoice.granted;
    final tokenReady = _token != null && _token!.isNotEmpty;
    return Column(
      key: FirebaseDebugTokenPanel.rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'رمز إشعارات Firebase',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          key: FirebaseDebugTokenPanel.statusKey,
          dense: true,
          title: const Text('Firebase'),
          subtitle: Text(_configured ? 'مفعّل' : 'غير مفعّل'),
        ),
        ListTile(
          key: FirebaseDebugTokenPanel.permissionKey,
          dense: true,
          title: const Text('إذن الإشعارات'),
          subtitle: Text(_permissionLabel(_permission, loaded: _loaded)),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(
              key: FirebaseDebugTokenPanel.copyKey,
              onPressed: tokenReady ? _copy : null,
              child: const Text('نسخ الرمز'),
            ),
            if (!granted)
              TextButton(
                key: FirebaseDebugTokenPanel.askKey,
                onPressed: _ask,
                child: const Text('السماح بالإشعارات'),
              ),
          ],
        ),
      ],
    );
  }
}

String _permissionLabel(
  NotificationPermissionChoice choice, {
  required bool loaded,
}) {
  if (!loaded) return '…';
  return switch (choice) {
    NotificationPermissionChoice.granted => 'مسموح',
    NotificationPermissionChoice.denied => 'غير مسموح',
    NotificationPermissionChoice.permanentlyDenied => 'مرفوض من الإعدادات',
  };
}
