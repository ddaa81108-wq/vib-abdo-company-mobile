import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/session_providers.dart';
import '../../../state/theme_controller.dart';
import '../../../state/section_providers.dart';
import '../../../state/home_operations_providers.dart';
import '../../../state/notification_providers.dart';
import '../../../ui/strings.dart';
import '../../../ui/theme.dart';
import '../../../ui/section_labels.dart';
import 'operations_style.dart';
import 'home_closing_card.dart';
import 'home_attention.dart';
import 'home_sections.dart';
import 'home_recent_activity.dart';

class OperationsHome extends ConsumerWidget {
  const OperationsHome({
    required this.screenKey,
    required this.settingsKey,
    super.key,
  });
  final Key screenKey, settingsKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final permissions = permissionsOf(ref);
    if (summary == null) return const Center(child: Text(AppStrings.loading));
    final reports = permissions.canRead(SectionKey.reports);
    final collections = permissions.canRead(SectionKey.collections);
    return ColoredBox(
      color: OperationsStyle.background(context),
      child: RefreshIndicator(
        onRefresh: () async {
          if (reports) {
            ref.invalidate(homeClosingProvider);
            ref.invalidate(homeActivityProvider);
          }
          if (collections) ref.invalidate(collectionsProvider);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationsCountProvider);
        },
        child: ListView(
          key: screenKey,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: OperationsStyle.panel(context, featured: true),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'VIB',
                          style: cairo(25, 800, color: OperationsStyle.gold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'مركز العمليات',
                          textAlign: TextAlign.end,
                          style: cairo(15, 700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.white.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      key: const Key('home-unified-search'),
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => context.go('/search'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ابحث عن عميل أو شركة أو معاملة',
                                style: cairo(
                                  11,
                                  500,
                                  color: const Color(0xFFE0E6EE),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (reports)
              const HomeClosingCard()
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: OperationsStyle.panel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'مرحبًا، ${summary.displayName}',
                      style: cairo(18, 700, color: context.look.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أقسامك ومتابعة عملك في مكان واحد',
                      style: cairo(12, 500, color: context.look.muted),
                    ),
                  ],
                ),
              ),
            if (collections) ...[
              const SizedBox(height: 12),
              const HomeAttention(),
            ],
            const SizedBox(height: 17),
            Text(
              'أقسام المنظومة',
              style: cairo(16, 700, color: context.look.ink),
            ),
            const SizedBox(height: 10),
            HomeSections(
              sections: summary.sections,
              settings: showsSettingsEntry(permissions),
              settingsKey: settingsKey,
            ),
            const SizedBox(height: 8),
            HomeRecentActivity(financial: reports),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
