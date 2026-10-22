import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/export_pdf_button.dart';
import '../../ui/widgets/soft_tile.dart';

class _AdminLink {
  const _AdminLink({
    required this.tileKey,
    required this.title,
    required this.path,
    required this.icon,
  });

  final Key tileKey;
  final String title;
  final String path;
  final IconData icon;
}

const _adminLinks = <_AdminLink>[
  _AdminLink(
    tileKey: Key('settings-link-employees'),
    title: AppStrings.employeesTile,
    path: '/settings/employee-totals',
    icon: Icons.groups_outlined,
  ),
  _AdminLink(
    tileKey: Key('settings-link-audit'),
    title: AppStrings.auditTile,
    path: '/settings/audit',
    icon: Icons.fact_check_outlined,
  ),
  _AdminLink(
    tileKey: Key('settings-link-operations'),
    title: AppStrings.operationsTile,
    path: '/settings/operations',
    icon: Icons.monitor_heart_outlined,
  ),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const screenKey = Key('screen-settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final manage = permissions.canDo(ManagementAction.settingsManage);
    final ledger = permissions.canViewFinancialLedger;
    if (!manage && !ledger) return const ForbiddenPane();
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      key: screenKey,
      padding: pagePadding(width),
      children: [
        const ScreenTitle(AppStrings.settings),
        const SizedBox(height: AppSpacing.md),
        if (manage)
          for (final link in _adminLinks)
            Card(
              margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
              clipBehavior: Clip.antiAlias,
              child: SoftTile(
                key: link.tileKey,
                leading: Icon(link.icon),
                title: link.title,
                trailing: forwardChevron(context),
                onTap: () => context.go(link.path),
              ),
            ),
        if (ledger) const _LedgerTile(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.noLanguage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Page total as an Arabic currency label. The server key (`LYD`, `EGP`) is
/// not shown beside the symbol.
String _ledgerTotal(MoneyFormatter money, String code, MoneyValue units) {
  final currency = Currency.fromCode(code);
  if (units.isInvalid || units.units == null) return MoneyValue.invalidLabel;
  if (currency == null) return money.formatNumber(units.units!);
  return money.formatOrDash(units, currency);
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canViewFinancialLedger) {
      return const SizedBox.shrink();
    }
    final page = ref.watch(financialLedgerProvider);
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final theme = Theme.of(context);
    return Card(
      key: const Key('financial-ledger'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.financialLedger, style: theme.textTheme.titleSmall),
            const ExportPdfButton(),
            page.when(
              loading: () => const SkeletonBox(height: 48),
              error: (error, _) => presentFailure(
                ref.read(errorHandlerProvider).toFailure(error),
                onRetry: online
                    ? () => ref.invalidate(financialLedgerProvider)
                    : null,
                retryKey: const Key('settings-retry'),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.pageTotals),
                  for (final entry in data.pageTotals.entries)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: AppSpacing.xs,
                      ),
                      child: MoneyText(
                        _ledgerTotal(money, entry.key, entry.value),
                        key: Key('ledger-total-${entry.key}'),
                      ),
                    ),
                  if (data.page.items.isEmpty)
                    const EmptyPane(message: AppStrings.emptyLedger),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
