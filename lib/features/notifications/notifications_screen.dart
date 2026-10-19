import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/notification_providers.dart';
import '../../state/section_providers.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/mutation_form.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const screenKey = Key('screen-notifications');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);
    final count = unread.asData?.value ?? page.asData?.value.unreadCount;
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.notifications),
        Text(
          '${AppStrings.unreadFull} ${count ?? AppStrings.dash}',
          key: const Key('unread-full'),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Text(AppStrings.insight),
          ),
        ),
        BusyAction(
          buttonKey: const Key('mark-all-read'),
          enabled: (count ?? 0) > 0,
          label: AppStrings.markAllRead,
          onSubmit: () => _all(ref),
        ),
        const SizedBox(height: AppSpacing.md),
        page.when(
          loading: () => const Text(AppStrings.loading),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (data) {
            if (data.items.isEmpty) return const EmptyPane(message: AppStrings.noNotifications);
            return Column(
              children: [
                for (final item in data.items)
                  _NoticeTile(
                    item: item,
                    onRead: () => _read(ref, item.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _read(WidgetRef ref, String id) async {
    await ref.read(apiLayerProvider).notifications.markRead(id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _all(WidgetRef ref) async {
    await ref.read(apiLayerProvider).notifications.markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }
}

class _NoticeTile extends StatefulWidget {
  const _NoticeTile({required this.item, required this.onRead});

  final NotificationDto item;
  final Future<void> Function() onRead;

  @override
  State<_NoticeTile> createState() => _NoticeTileState();
}

class _NoticeTileState extends State<_NoticeTile> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('notice-${widget.item.id}'),
      title: Text(
        (widget.item.title != null && widget.item.title!.isNotEmpty)
            ? widget.item.title!
            : notificationFallback(widget.item.action),
      ),
      subtitle: Text(
        [
          if (widget.item.body != null && widget.item.body!.isNotEmpty) widget.item.body!,
          formatIsoDate(widget.item.createdAt),
        ].join(' · '),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _busy ? null : _run,
    );
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRead();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
