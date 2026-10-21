import 'package:flutter/material.dart';

import '../strings.dart';
import '../tokens.dart';

/// Banner for [signedOutNotice]. One instance on the login screen, not a dialog
/// per failed request.
class SessionExpiredNotice extends StatelessWidget {
  const SessionExpiredNotice({required this.message, super.key});

  final String message;

  static const noticeKey = Key('session-expired-notice');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: noticeKey,
      color: scheme.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
