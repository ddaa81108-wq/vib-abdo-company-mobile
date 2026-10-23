import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error_handling/error_handler.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  static const screenKey = Key('splash');
  static const retryKey = Key('splash-retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider);
    if (startup.hasError) {
      final theme = Theme.of(context);
      final failure = ref.watch(errorHandlerProvider).toFailure(startup.error!);
      if (failure.isForbidden) {
        return const Scaffold(key: screenKey, body: ForbiddenPane());
      }
      final message = failureText(failure);
      return Scaffold(
        key: screenKey,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: retryKey,
                    onPressed: () => ref.invalidate(startupProvider),
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const Scaffold(
      key: screenKey,
      body: Center(child: Text(AppStrings.loading)),
    );
  }
}
