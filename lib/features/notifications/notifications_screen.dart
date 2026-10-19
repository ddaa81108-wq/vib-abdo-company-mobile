import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/notification_providers.dart';
import '../../state/section_providers.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

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
        FilledButton(
          key: const Key('mark-all-read'),
          onPressed: (count ?? 0) == 0 ? null : () => _all(ref),
          child: const Text(AppStrings.markAllRead),
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
                  ListTile(
                    key: Key('notice-${item.id}'),
                    title: Text(
                      (item.title != null && item.title!.isNotEmpty)
                          ? item.title!
                          : notificationFallback(item.action),
                    ),
                    subtitle: Text(
                      [
                        if (item.body != null && item.body!.isNotEmpty) item.body!,
                        formatIsoDate(item.createdAt),
                      ].join(' · '),
                    ),
                    onTap: () => _read(ref, item.id),
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
