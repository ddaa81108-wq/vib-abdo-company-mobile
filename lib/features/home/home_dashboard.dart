import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../models/home_summary.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import 'home_shell.dart';

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  static const screenKey = Key('home-dashboard');
  static const retryKey = Key('home-retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final dashboard = ref.watch(homeDashboardProvider);
    final online = ref.watch(onlineProvider);
    final permissions = permissionsOf(ref);
    final money = ref.watch(apiLayerProvider).money;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    if (summary == null) {
      return const Center(child: Text(AppStrings.loading));
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeDashboardProvider);
        ref.invalidate(unreadCountProvider);
        await ref.read(homeDashboardProvider.future);
      },
      child: ListView(
        key: screenKey,
        padding: pagePadding(width),
        children: [
          if (dashboard.hasError)
            ErrorPane(
              message: AppStrings.homeError,
              onRetry: online
                  ? () {
                      ref.invalidate(homeDashboardProvider);
                    }
                  : null,
              retryKey: retryKey,
            )
          else if (dashboard.isLoading)
            const SkeletonBox(key: HomeShell.homeLoadingKey, height: 88)
          else if (dashboard.asData?.value case final home?) ...[
            if (home.businessDate != null)
              Text(home.businessDate!, key: const Key('home-business-date')),
            const SizedBox(height: AppSpacing.md),
            Text(AppStrings.homeCardsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (_visibleCards(home, permissions).isEmpty && (home.oldDebts == null))
              const Text(AppStrings.noSummaries)
            else
              LayoutBuilder(
                builder: (context, constraints) => _SummaryGrid(
                  cards: _visibleCards(home, permissions),
                  money: money,
                  width: constraints.maxWidth,
                  columns: AppBreakpoints.cardColumns(width),
                ),
              ),
            if (home.oldDebts != null &&
                (permissions.canRead(SectionKey.customers) ||
                    permissions.canRead(SectionKey.companies))) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.oldDebtsTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              if (_visibleDebts(home, permissions).isEmpty)
                const Text(AppStrings.emptyTicker)
              else ...[
                for (final debt in _visibleDebts(home, permissions))
                  _DebtRow(debt: debt, money: money),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('show-all-home'),
                    onPressed: () => context.go('/customers'),
                    child: const Text(AppStrings.showAll),
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
          if (summary.actions.isNotEmpty) ...[
            Text(AppStrings.actionsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                for (final action in summary.actions)
                  TextButton(
                    key: HomeShell.actionKey(action),
                    onPressed: online ? () => context.go(actionPath(action)) : null,
                    child: Text(actionLabel(action)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text(AppStrings.sectionsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.sectionsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary.sections.isEmpty)
            const Text(AppStrings.noSections)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = AppBreakpoints.cardColumns(constraints.maxWidth);
                final tileWidth =
                    ((constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns)
                        .clamp(96.0, constraints.maxWidth);
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final section in summary.sections)
                      SizedBox(
                        width: tileWidth,
                        child: _sectionTile(context, section, summary, online),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  List<HomeSummaryDto> _visibleCards(HomeDto home, PermissionService permissions) {
    return [
      for (final card in home.summaries)
        if (sectionIsReadable(card.section, permissions)) card,
    ];
  }

  List<OldDebtDto> _visibleDebts(HomeDto home, PermissionService permissions) {
    return [
      for (final debt in home.oldDebts ?? const <OldDebtDto>[])
        if (sectionIsReadable(debt.section, permissions)) debt,
    ];
  }

  Widget _sectionTile(
    BuildContext context,
    SectionKey section,
    HomeSummary summary,
    bool online,
  ) {
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: HomeShell.sectionKey(section),
        visualDensity: VisualDensity.compact,
        leading: Icon(sectionIcon(section)),
        title: Text(sectionLabel(section)),
        onTap: () => context.go(sectionPath(section)),
        trailing: summary.writableSections.contains(section)
            ? TextButton(
                key: HomeShell.writeKey(section),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: online ? () => context.go(sectionPath(section)) : null,
                child: Text(_writeLabel(section)),
              )
            : null,
      ),
    );
  }

  String _writeLabel(SectionKey section) => switch (section) {
    SectionKey.customers => AppStrings.addCustomer,
    SectionKey.companies => AppStrings.addCompany,
    SectionKey.libyanDeposits || SectionKey.egyptianDeposits => AppStrings.addDeposit,
    SectionKey.collections => AppStrings.submitReceipt,
    SectionKey.purchases => AppStrings.add,
    SectionKey.treasury => AppStrings.cashIn,
    SectionKey.masraweya => AppStrings.save,
    SectionKey.reports => AppStrings.refresh,
  };
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.cards,
    required this.money,
    required this.width,
    required this.columns,
  });

  final List<HomeSummaryDto> cards;
  final MoneyFormatter money;
  final double width;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final card in cards)
          SizedBox(
            width: ((width - AppSpacing.md * (columns - 1)) / columns).clamp(96, width),
            child: _SummaryCard(card: card, money: money),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card, required this.money});

  final HomeSummaryDto card;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final tone = toneColor(context.statusColors, card.tone);
    final value = card.currency == null
        ? AppStrings.dash
        : money.formatOrDash(card.valueUnits, card.currency!);
    final status = reportStatusLabel(card.status);
    return Card(
      key: HomeShell.summaryKey(card.key),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            MoneyText(value, style: context.textExtras.amountLarge.copyWith(color: tone)),
            if (status != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ReportStatusChip(status: card.status),
            ],
            if (card.note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(card.note!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.money});

  final OldDebtDto debt;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final visual = ageVisual(
      colors: context.statusColors,
      ageStatus: debt.ageStatus,
      section: null,
      serverLabel: debt.ageStatusLabel,
    );
    final amount = debt.currency == null
        ? AppStrings.dash
        : money.formatOrDash(debt.balanceUnits, debt.currency!);
    return Card(
      key: Key('old-debt-${debt.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(debt.name),
        subtitle: Text(
          [
            amount,
            if (visual.label != null) visual.label!,
            if (debt.debtAgeDays != null) sinceDays(debt.debtAgeDays),
          ].join(' · '),
        ),
      ),
    );
  }
}
