import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/notification_announcer.dart';
import '../../state/notification_providers.dart';
import '../../state/section_providers.dart';
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

  /// How long a banner stays if it is not tapped or swiped away.
  static const hold = Duration(seconds: 5);

  @override
  ConsumerState<ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState
    extends ConsumerState<ForegroundNotificationBanner>
    with WidgetsBindingObserver {
  AppNotification? _note;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _hide?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// One card. A newer row replaces it and starts the hold again.
  /// Nothing is marked read.
  void _present(AppNotification note) {
    _hide?.cancel();
    setState(() => _note = note);
    _hide = Timer(ForegroundNotificationBanner.hold, () {
      if (!mounted || _note?.notificationId != note.notificationId) return;
      setState(() => _note = null);
    });
  }

  void _clear() {
    _hide?.cancel();
    _hide = null;
    if (!mounted) return;
    setState(() => _note = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(ref.read(notificationAnnouncerProvider).stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(foregroundNotificationsProvider, (previous, next) {
      final note = next.asData?.value;
      if (note == null) return;
      _present(note);
      unawaited(_announce(note));
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
                child: Dismissible(
                  key: ValueKey('banner-${note.notificationId}'),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => _clear(),
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
          ),
      ],
    );
  }

  Future<void> _announce(AppNotification note) async {
    Map<String, dynamic> preferences = const {};
    try {
      preferences = await ref.read(notificationPrefsProvider.future);
    } catch (_) {
      preferences = const {};
    }
    if (!mounted) return;
    await announceNewNotification(
      note: note,
      preferences: preferences,
      announcer: ref.read(notificationAnnouncerProvider),
    );
  }

  Future<void> _open(AppNotification note) async {
    _clear();
    final result = await ref
        .read(notificationOpenSeamProvider)
        .open(note, origin: NotificationOpenOrigin.banner);
    if (!mounted) return;
    showNotificationOpenResult(context, result);
  }
}
