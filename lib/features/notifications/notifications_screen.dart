import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error_handling/error_handler.dart';
import '../../notifications/push_providers.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
import '../../ui/widgets/soft_tile.dart';
import 'notification_content.dart';
import 'notification_open_seam.dart';
import 'notification_permission.dart';
import 'notification_permission_registration.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static const screenKey = Key('screen-notifications');
  static const retryKey = Key('notifications-retry');

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeExplain();
    });
  }

  /// First visit to this screen in the provider scope. Already granted skips
  /// the dialog. A denial explains first and requests only after agreement.
  Future<void> _maybeExplain() async {
    if (!mounted) return;
    if (ref.read(notificationPermissionPromptedProvider)) return;
    ref.read(notificationPermissionPromptedProvider.notifier).mark();
    final service = ref.read(notificationPermissionServiceProvider);
    final NotificationPermissionChoice status;
    try {
      status = await service.status();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (status == NotificationPermissionChoice.granted) {
      await _syncRegistration();
      return;
    }
    if (status == NotificationPermissionChoice.permanentlyDenied) {
      await _syncRegistration();
      if (!mounted) return;
      await _showDenied();
      return;
    }
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _permissionDialog(
        dialogContext,
        key: const Key('notification-permission-explain'),
        title: AppStrings.notificationPermissionTitle,
        message: AppStrings.notificationPermissionBody,
        actions: [
          TextButton(
            key: const Key('notification-permission-later'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.notificationPermissionLater),
          ),
          FilledButton(
            key: const Key('notification-permission-agree'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.notificationPermissionAgree),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (agreed != true) {
      await _syncRegistration();
      return;
    }
    final NotificationPermissionChoice next;
    try {
      next = await service.request();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await _syncRegistration();
    if (!mounted) return;
    if (next != NotificationPermissionChoice.granted) await _showDenied();
  }

  /// A grant registers. A denial unregisters. The opener still owns mark-read.
  Future<void> _syncRegistration() {
    final session = ref.read(sessionStateProvider);
    return registerForNotificationPermission(
      signedIn: session is SessionAuthenticated,
      permission: ref.read(notificationPermissionServiceProvider),
      registrar: ref.read(deviceTokenRegistrarProvider),
    );
  }

  Future<void> _showDenied() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _permissionDialog(
        dialogContext,
        key: const Key('notification-permission-denied'),
        title: AppStrings.notificationPermissionTitle,
        message: AppStrings.notificationPermissionDenied,
        actions: [
          TextButton(
            key: const Key('notification-permission-later'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.notificationPermissionLater),
          ),
          FilledButton(
            key: const Key('notification-permission-settings'),
            onPressed: () async {
              await ref
                  .read(notificationPermissionServiceProvider)
                  .openSettings();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text(AppStrings.notificationPermissionSettings),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsStateProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final online = ref.watch(onlineProvider);
    final count = unread.asData?.value;
    if (state is NotificationsForbidden) {
      return const KeyedSubtree(
        key: NotificationsScreen.screenKey,
        child: ForbiddenPane(),
      );
    }
    return ListView(
      key: NotificationsScreen.screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.notifications),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${AppStrings.unreadFull} ${count ?? AppStrings.dash}',
          key: const Key('unread-full'),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BusyAction(
            buttonKey: const Key('mark-all-read'),
            enabled: online && (count ?? 0) > 0,
            label: AppStrings.markAllRead,
            onSubmit: () => _markAll(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _body(state, online),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.noLanguage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _body(NotificationsState state, bool online) {
    return switch (state) {
      NotificationsLoading() => const SkeletonBox(
        key: Key('notifications-loading'),
        height: 72,
      ),
      NotificationsEmpty() => const EmptyPane(
        title: AppStrings.notifications,
        message: AppStrings.noNotifications,
        icon: Icons.notifications_none,
      ),
      NotificationsFailure(:final failure) => ErrorPane(
        message: failure.message,
        retryKey: NotificationsScreen.retryKey,
        onRetry: online ? () => ref.invalidate(notificationsProvider) : null,
      ),
      NotificationsReady(:final items) => Column(
        children: [for (final item in items) _NoticeTile(item: item)],
      ),
      NotificationsForbidden() => const SizedBox.shrink(),
    };
  }

  Future<void> _markAll(BuildContext context) async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (error) {
      if (!context.mounted) return;
      showFailureSnackBar(
        context,
        ref.read(errorHandlerProvider).toFailure(error),
      );
    }
  }
}

class _NoticeTile extends ConsumerWidget {
  const _NoticeTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unread = !item.isRead;
    final headline = notificationHeadline(item);
    final secondary = notificationSecondaryLines(item);
    final label =
        '${unread ? AppStrings.unreadLabel : AppStrings.readLabel} $headline';
    return Card(
      key: Key('notice-card-${item.notificationId}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      color: unread ? theme.colorScheme.primaryContainer : null,
      child: Semantics(
        label: label,
        button: true,
        container: true,
        child: InkWell(
          key: Key('notice-${item.notificationId}'),
          onTap: () => _open(context, ref),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 6,
                      end: AppSpacing.sm,
                    ),
                    child: Container(
                      key: Key('notice-unread-dot-${item.notificationId}'),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        key: Key('notice-headline-${item.notificationId}'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      for (final line in secondary) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(line),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notificationWhen(item),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                forwardChevron(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(notificationOpenSeamProvider)
        .open(item, origin: NotificationOpenOrigin.list);
    if (!context.mounted) return;
    showNotificationOpenResult(context, result);
  }
}

Widget _permissionDialog(
  BuildContext context, {
  required Key key,
  required String title,
  required String message,
  required List<Widget> actions,
}) {
  final tight = MediaQuery.sizeOf(context).width <= 360;
  return AlertDialog(
    key: key,
    scrollable: true,
    insetPadding: EdgeInsets.symmetric(
      horizontal: tight ? 12 : 40,
      vertical: tight ? 16 : 24,
    ),
    title: Text(title),
    content: Text(message),
    actions: actions,
  );
}
