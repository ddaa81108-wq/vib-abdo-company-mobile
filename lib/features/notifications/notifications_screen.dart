import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/notification_providers.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';
import '../../ui/widgets/soft_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const screenKey = Key('screen-notifications');
  static const retryKey = Key('notifications-retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final online = ref.watch(onlineProvider);
    final count = unread.asData?.value ?? page.asData?.value.unreadCount;
    final theme = Theme.of(context);
    return ListView(
      key: screenKey,
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
            onSubmit: () => _all(ref, context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        KeptData<NotificationsPage>(
          value: page,
          resetKey: 'notifications',
          retryKey: retryKey,
          onRetry: online ? () => ref.invalidate(notificationsProvider) : null,
          messageOf: (error) =>
              ref.read(errorHandlerProvider).toFailure(error).message,
          loading: const SkeletonBox(
            key: Key('notifications-loading'),
            height: 72,
          ),
          builder: (data) {
            if (data.items.isEmpty) {
              return const EmptyPane(
                title: AppStrings.notifications,
                message: AppStrings.noNotifications,
                icon: Icons.notifications_none,
              );
            }
            return Column(
              children: [
                for (final item in data.items)
                  _NoticeTile(
                    item: item,
                    online: online,
                    onRead: () => _read(ref, item),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(AppStrings.noLanguage, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Future<({String? error, String? path})> _read(
    WidgetRef ref,
    NotificationDto item,
  ) async {
    try {
      await ref.read(apiLayerProvider).notifications.markRead(item.id);
    } catch (error) {
      return (
        error: ref.read(errorHandlerProvider).toFailure(error).message,
        path: null,
      );
    }
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
    return (error: null, path: notificationPath(item.section, item.entityId));
  }

  Future<void> _all(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(apiLayerProvider).notifications.markAllRead();
    } catch (error) {
      final message = ref.read(errorHandlerProvider).toFailure(error).message;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }
}

class _NoticeTile extends StatefulWidget {
  const _NoticeTile({
    required this.item,
    required this.online,
    required this.onRead,
  });

  final NotificationDto item;
  final bool online;
  final Future<({String? error, String? path})> Function() onRead;

  @override
  State<_NoticeTile> createState() => _NoticeTileState();
}

class _NoticeTileState extends State<_NoticeTile> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (widget.item.title != null && widget.item.title!.isNotEmpty)
        ? widget.item.title!
        : notificationFallback(widget.item.action);
    final body = widget.item.body;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      color: widget.item.isRead ? null : theme.colorScheme.primaryContainer,
      child: InkWell(
        key: Key('notice-${widget.item.id}'),
        onTap: _busy ? null : _run,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.isRead
                          ? AppStrings.readLabel
                          : AppStrings.unreadLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(title, style: theme.textTheme.titleSmall),
                    if (body != null && body.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(body),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatIsoDate(widget.item.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_busy) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              forwardChevron(context),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run() async {
    if (_busy) return;
    final path = notificationPath(widget.item.section, widget.item.entityId);
    if (!widget.online) {
      if (path != null && mounted) context.go(path);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.onRead();
      if (!mounted) return;
      if (result.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.error!)));
        return;
      }
      final next = result.path;
      if (next != null) context.go(next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
