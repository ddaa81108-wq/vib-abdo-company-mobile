import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/notification_providers.dart';
import '../../state/section_providers.dart';
import '../../ui/presentation.dart';
import '../../ui/section_labels.dart';
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
          onSubmit: () => _all(ref, context),
        ),
        const SizedBox(height: AppSpacing.md),
        KeptData<NotificationsPage>(
          value: page,
          resetKey: 'notifications',
          onRetry: () => ref.invalidate(notificationsProvider),
          messageOf: (error) =>
              ref.read(errorHandlerProvider).toFailure(error).message,
          loading: const Text(AppStrings.loading),
          builder: (data) {
            if (data.items.isEmpty) {
              return const EmptyPane(message: AppStrings.noNotifications);
            }
            return Column(
              children: [
                for (final item in data.items)
                  _NoticeTile(item: item, onRead: () => _read(ref, item)),
              ],
            );
          },
        ),
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
  const _NoticeTile({required this.item, required this.onRead});

  final NotificationDto item;
  final Future<({String? error, String? path})> Function() onRead;

  @override
  State<_NoticeTile> createState() => _NoticeTileState();
}

class _NoticeTileState extends State<_NoticeTile> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.item.title != null && widget.item.title!.isNotEmpty)
        ? widget.item.title!
        : notificationFallback(widget.item.action);
    final subtitle = [
      if (widget.item.body != null && widget.item.body!.isNotEmpty)
        widget.item.body!,
      formatIsoDate(widget.item.createdAt),
    ].join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: Key('notice-${widget.item.id}'),
        onTap: _busy ? null : _run,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(subtitle),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.onRead();
      if (!mounted) return;
      if (result.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.error!)));
        return;
      }
      final path = result.path;
      if (path != null) context.go(path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
