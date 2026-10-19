import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/unread_badge.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const shellKey = Key('home-shell');
  static const logoutKey = Key('logout-button');
  static const roleKey = Key('role-label');

  static Key sectionKey(SectionKey section) => Key('section-${section.key}');
  static Key writeKey(SectionKey section) => Key('write-${section.key}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final unread = ref.watch(unreadCountProvider);
    final theme = Theme.of(context);

    if (summary == null) {
      return const Scaffold(body: Center(child: Text(AppStrings.loading)));
    }

    return Scaffold(
      key: shellKey,
      appBar: AppBar(
        title: const Text(AppStrings.homeTitle),
        actions: [
          UnreadBadge(count: unread.asData?.value),
          IconButton(
            key: logoutKey,
            tooltip: AppStrings.logout,
            onPressed: () => ref.read(sessionStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(AppStrings.signedInAs, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            summary.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(roleLabel(summary.accountRole), key: roleKey),
          if (summary.mustChangePassword) ...[
            const SizedBox(height: 16),
            const _PasswordChangeBanner(),
          ],
          const SizedBox(height: 28),
          Text(AppStrings.sectionsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            AppStrings.sectionsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (summary.sections.isEmpty)
            const Text(AppStrings.noSections)
          else
            for (final section in summary.sections)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: sectionKey(section),
                  enabled: false,
                  title: Text(sectionLabel(section)),
                  subtitle: const Text(AppStrings.comingSoon),
                  trailing: summary.writableSections.contains(section)
                      ? TextButton(
                          key: writeKey(section),
                          onPressed: null,
                          child: const Text(AppStrings.writeAction),
                        )
                      : const Icon(Icons.lock_outline),
                ),
              ),
        ],
      ),
    );
  }
}

class _PasswordChangeBanner extends StatelessWidget {
  const _PasswordChangeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(AppStrings.passwordChangeRequired),
      ),
    );
  }
}
