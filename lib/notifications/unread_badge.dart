import 'package:flutter/material.dart';

import '../ui/presentation.dart';
import '../ui/strings.dart';
import '../ui/theme.dart';

/// Server unread count in the top bar. Zero draws no badge. 99 and above draw "99".
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({required this.count, this.onPressed, super.key});

  /// Null while the server count is unknown. Zero is a real server value.
  final int? count;
  final VoidCallback? onPressed;

  static const badgeKey = Key('unread-badge');
  static const buttonKey = Key('notifications-button');

  @override
  Widget build(BuildContext context) {
    final label = badgeLabel(count);
    final colors = context.statusColors;
    return Semantics(
      label: AppStrings.notifications,
      button: true,
      child: IconButton(
        key: buttonKey,
        tooltip: AppStrings.bell,
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: label != null,
          backgroundColor: colors.badgeBg,
          label: label == null
              ? null
              : Text(
                  label,
                  key: badgeKey,
                  style: context.textExtras.badge.copyWith(color: colors.onStatus),
                ),
          child: Icon(
            (count ?? 0) > 0 ? Icons.notifications_active_outlined : Icons.notifications_none,
            size: 19,
          ),
        ),
      ),
    );
  }
}
