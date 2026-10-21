import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/notification_providers.dart';
import '../../ui/tokens.dart';
import 'notification_content.dart';
import 'notification_open_seam.dart';

/// In-app banner for [foregroundNotificationsProvider].
///
/// The stream emits only a newly seen unread row. The card sits above the
/// shell, including the phone bottom bar, and a tap uses the open seam with
/// [NotificationOpenOrigin.banner].
class ForegroundNotificationBanner extends ConsumerStatefulWidget {
  const ForegroundNotificationBanner({required this.child, super.key});

  final Widget child;

  static const bannerKey = Key('notification-banner');

  @override
  ConsumerState<ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState
    extends ConsumerState<ForegroundNotificationBanner> {
  AppNotification? _note;

  @override
  Widget build(BuildContext context) {
    ref.listen(foregroundNotificationsProvider, (previous, next) {
      final note = next.asData?.value;
      if (note == null) return;
      setState(() => _note = note);
    });
    final note = _note;
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (note != null)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Material(
                  elevation: 6,
                  color: theme.colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: InkWell(
                    key: ForegroundNotificationBanner.bannerKey,
                    onTap: () => _open(note),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      child: Text(
                        notificationHeadline(note),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _open(AppNotification note) async {
    setState(() => _note = null);
    final result = await ref
        .read(notificationOpenSeamProvider)
        .open(note, origin: NotificationOpenOrigin.banner);
    if (!mounted) return;
    showNotificationOpenResult(context, result);
  }
}
