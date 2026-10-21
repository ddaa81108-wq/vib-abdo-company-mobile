import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/section_providers.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

/// Duplicate and similar names from `GET /api/{section}/suggestions`.
///
/// A failed lookup does not block creation. An empty name does not call the
/// server.
class AccountNameSuggestions extends ConsumerWidget {
  const AccountNameSuggestions({
    required this.section,
    required this.query,
    super.key,
  });

  final AccountSection section;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final suggestions = ref.watch(
      accountNameSuggestionsProvider((section, trimmed)),
    );
    return suggestions.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('account-suggestions'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.similarNames,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final item in items)
              ListTile(
                key: ValueKey('suggestion-${item.id}'),
                dense: true,
                contentPadding: EdgeInsetsDirectional.zero,
                title: Text(item.name),
                subtitle: item.phone == null ? null : LtrText(item.phone!),
              ),
          ],
        );
      },
    );
  }
}
