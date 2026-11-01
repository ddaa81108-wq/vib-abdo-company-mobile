import 'package:flutter/material.dart';

import '../ui/presentation.dart';
import '../ui/strings.dart';
import '../ui/theme.dart';

/// Server unread count in the top bar. Zero draws no badge. Above 99 draws "99+".
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
        icon: _BellWithCount(
          label: label,
          background: colors.badgeBg,
          style: context.textExtras.badge.copyWith(color: colors.onStatus),
          icon: (count ?? 0) > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
        ),
      ),
    );
  }
}

/// The bell with its count centred on the bell's top end corner (top left
/// in RTL), resting just above the bell, so even "99+" stays in the
/// button's own margin. Its text is capped at 1.2x, so large text never
/// covers the bell.
class _BellWithCount extends StatelessWidget {
  const _BellWithCount({
    required this.label,
    required this.background,
    required this.style,
    required this.icon,
  });

  final String? label;
  final Color background;
  final TextStyle style;
  final IconData icon;

  static const _iconSize = 19.0;

  /// How far the pill reaches down over the bell's top edge.
  static const _overlap = 2.0;

  @override
  Widget build(BuildContext context) {
    final bell = Icon(icon, size: _iconSize);
    final label = this.label;
    if (label == null) return bell;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bell,
        PositionedDirectional(
          top: -16 + _overlap,
          start: _iconSize,
          child: FractionalTranslation(
            // Centre the pill on the corner (its start edge is there).
            translation: Offset(rtl ? 0.5 : -0.5, 0),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Badge(
                backgroundColor: background,
                label: Text(
                  label,
                  key: UnreadBadge.badgeKey,
                  // "99+" reads left to right in the RTL app bar too.
                  textDirection: TextDirection.ltr,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
