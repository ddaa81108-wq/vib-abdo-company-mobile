import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_providers.dart';
import '../strings.dart';
import '../tokens.dart';

/// Asks before calling the existing logout. Cancel leaves the session as it is.
Future<void> requestLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const LogoutConfirmDialog(),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(sessionStateProvider.notifier).logout();
}

class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

  static const dialogKey = Key('logout-dialog');
  static const confirmKey = Key('logout-confirm');
  static const cancelKey = Key('logout-cancel');

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      key: dialogKey,
      scrollable: true,
      insetPadding: EdgeInsets.symmetric(
        horizontal: width <= 360 ? AppSpacing.lg : AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      title: const Text(AppStrings.logout),
      content: const Text(AppStrings.logoutConfirm),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(AppStrings.logout),
        ),
      ],
    );
  }
}
