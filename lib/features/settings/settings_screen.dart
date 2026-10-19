import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const screenKey = Key('screen-settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final allowed = permissions.canDo(ManagementAction.settingsManage);
    if (!allowed) return const ForbiddenPane();
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const ScreenTitle(AppStrings.settings),
        const SizedBox(height: AppSpacing.md),
        _Tile(title: AppStrings.employeesTile, body: AppStrings.unavailable),
        _Tile(title: AppStrings.auditTile, body: AppStrings.unavailable),
        _Tile(title: AppStrings.operationsTile, body: AppStrings.unavailable),
        const _LedgerTile(),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.noLanguage, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: ListTile(
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(financialLedgerProvider);
    final money = ref.watch(apiLayerProvider).money;
    return Card(
      key: const Key('financial-ledger'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.financialLedger, style: Theme.of(context).textTheme.titleSmall),
            page.when(
              loading: () => const SkeletonBox(height: 48),
              error: (error, _) => Text(ref.read(errorHandlerProvider).toFailure(error).message),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.pageTotals),
                  for (final entry in data.pageTotals.entries)
                    Text(
                      '${entry.key} ${money.formatOrDash(entry.value, Currency.fromCode(entry.key) ?? Currency.lyd)}',
                    ),
                  if (data.page.items.isEmpty) const Text(AppStrings.emptyLedger),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
