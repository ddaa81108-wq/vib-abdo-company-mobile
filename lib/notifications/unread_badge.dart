import 'package:flutter/material.dart';

import '../ui/strings.dart';

/// Shows the server unread count as text. A missing or zero count draws no number.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({required this.count, super.key});

  /// Null while the server count is unknown. Zero is a real server value.
  final int? count;

  static const badgeKey = Key('unread-badge');

  @override
  Widget build(BuildContext context) {
    final label = count == null || count == 0 ? null : '$count';
    return Semantics(
      label: AppStrings.notifications,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                key: badgeKey,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
