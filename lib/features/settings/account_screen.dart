import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/soft_tile.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const screenKey = Key('screen-account');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final session = ref.watch(sessionStateProvider);
    final profile = session is SessionAuthenticated ? session.profile : null;
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final online = ref.watch(onlineProvider);
    final prefs = ref.watch(notificationPrefsProvider);
    final theme = Theme.of(context);
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.myAccount),
        const SizedBox(height: AppSpacing.md),
        if (summary != null)
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.signedInAs,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(summary.displayName, style: theme.textTheme.titleMedium),
                  Text(roleLabel(summary.role)),
                  if (profile != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    LtrText(
                      profile.username,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            key: const Key('theme-switch'),
            title: const Text(AppStrings.appearance),
            subtitle: Text(dark ? AppStrings.themeDark : AppStrings.themeLight),
            value: dark,
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).setDark(value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.notificationPrefs,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                prefs.when(
                  loading: () => const SkeletonBox(
                    key: Key('account-prefs-loading'),
                    height: 48,
                  ),
                  error: (error, _) => presentFailure(
                    ref.read(errorHandlerProvider).toFailure(error),
                    onRetry: online
                        ? () => ref.invalidate(notificationPrefsProvider)
                        : null,
                    retryKey: const Key('account-prefs-retry'),
                  ),
                  data: (data) => _PrefSwitches(data: data, online: online),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SoftTile(
            key: const Key('account-password'),
            leading: const Icon(Icons.password_outlined),
            title: AppStrings.changePassword,
            trailing: forwardChevron(context),
            onTap: online ? () => context.push('/account/password') : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SoftTile(
            key: const Key('account-logout'),
            leading: mirrorInRtl(context, Icons.logout),
            title: AppStrings.logout,
            onTap: () => ref.read(sessionStateProvider.notifier).logout(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.noLanguage, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _PrefSwitches extends ConsumerStatefulWidget {
  const _PrefSwitches({required this.data, required this.online});

  final Map<String, dynamic> data;
  final bool online;

  @override
  ConsumerState<_PrefSwitches> createState() => _PrefSwitchesState();
}

class _PrefSwitchesState extends ConsumerState<_PrefSwitches> {
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final enabled = widget.online && !_saving;
    return Column(
      children: [
        SwitchListTile(
          key: const Key('sound-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.sound),
          value: data['soundEnabled'] == true,
          onChanged: enabled
              ? (value) => _save({...data, 'soundEnabled': value})
              : null,
        ),
        SwitchListTile(
          key: const Key('speech-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text(AppStrings.speech),
          value: data['speechEnabled'] == true,
          onChanged: enabled
              ? (value) => _save({...data, 'speechEnabled': value})
              : null,
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _save(Map<String, dynamic> next) async {
    if (_saving || !widget.online) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiLayerProvider).notifications.updatePreferences(next);
      ref.invalidate(notificationPrefsProvider);
    } catch (error) {
      ref.invalidate(notificationPrefsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.prefsFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
