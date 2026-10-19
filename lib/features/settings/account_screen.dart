import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const screenKey = Key('screen-account');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final prefs = ref.watch(notificationPrefsProvider);
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.myAccount),
        if (summary != null) ...[
          Text(summary.displayName),
          const SizedBox(height: AppSpacing.md),
        ],
        SwitchListTile(
          key: const Key('theme-switch'),
          title: Text(dark ? AppStrings.themeDark : AppStrings.themeLight),
          value: dark,
          onChanged: (value) => ref.read(themeModeProvider.notifier).setDark(value),
        ),
        const Text(AppStrings.notificationPrefs),
        prefs.when(
          loading: () => const Text(AppStrings.loading),
          error: (error, _) => ErrorPane(
            message: ref.read(errorHandlerProvider).toFailure(error).message,
            onRetry: () => ref.invalidate(notificationPrefsProvider),
          ),
          data: (data) => Column(
            children: [
              SwitchListTile(
                key: const Key('sound-switch'),
                title: const Text(AppStrings.sound),
                value: data['soundEnabled'] == true,
                onChanged: (value) => _save(ref, {...data, 'soundEnabled': value}),
              ),
              SwitchListTile(
                key: const Key('speech-switch'),
                title: const Text(AppStrings.speech),
                value: data['speechEnabled'] == true,
                onChanged: (value) => _save(ref, {...data, 'speechEnabled': value}),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          key: const Key('account-password'),
          title: const Text(AppStrings.changePassword),
          onTap: () => context.push('/account/password'),
        ),
        ListTile(
          title: const Text(AppStrings.logout),
          onTap: () => ref.read(sessionStateProvider.notifier).logout(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.noLanguage, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Future<void> _save(WidgetRef ref, Map<String, dynamic> next) async {
    try {
      await ref.read(apiLayerProvider).notifications.updatePreferences(next);
      ref.invalidate(notificationPrefsProvider);
    } catch (error) {
      ref.invalidate(notificationPrefsProvider);
    }
  }
}
