import 'package:flutter/material.dart';

import '../tokens.dart';

/// Mirrors icons that do not opt into [IconData.matchTextDirection].
Widget mirrorInRtl(BuildContext context, IconData icon, {double? size}) {
  final child = Icon(icon, size: size);
  if (icon.matchTextDirection ||
      Directionality.of(context) != TextDirection.rtl) {
    return child;
  }
  return Transform.flip(flipX: true, child: child);
}

/// Disclosure chevron. [Icons.chevron_right] follows [Directionality], so in
/// Arabic it points toward the start of the line.
Widget forwardChevron(BuildContext context) {
  return Icon(Icons.chevron_right, textDirection: Directionality.of(context));
}

/// A tappable row whose title and subtitle wrap instead of clipping.
///
/// ListTile keeps a fixed height and overflows at large text scales.
class SoftTile extends StatelessWidget {
  const SoftTile({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.titleColor,
    this.subtitleColor,
    this.iconColor,
    this.selectedColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? iconColor;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(color: titleColor);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: subtitleColor,
    );
    return Material(
      color: selected
          ? (selectedColor ?? theme.colorScheme.primaryContainer)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: iconColor, size: 22),
                    child: leading!,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(subtitle!, style: subtitleStyle),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconTheme(
                    data: IconThemeData(color: iconColor),
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
