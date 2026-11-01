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

/// Readable debt sections in first-seen order. Each one gets its own control.
List<String> homeShowAllSections(
  Iterable<String> sections,
  PermissionService permissions,
) {
  final ordered = <String>[];
  for (final section in sections) {
    if (ordered.contains(section)) continue;
    if (homeShowAllPath(section, permissions) == null) continue;
    ordered.add(section);
  }
  return ordered;
}

SectionKey? sectionKeyFor(String section) {
  for (final key in SectionKey.values) {
    if (key.key == section) return key;
  }
  return null;
}

int homeCardColumns(double width, double textScale) {
  if (textScale >= 1.3) return 1;
  return AppBreakpoints.cardColumns(width);
}

/// Columns for the home icon grid. Two on a phone (as in Ali's reference),
/// more on wider screens, one at a large text scale so labels never clip.
int homeTileColumns(double width, double textScale) {
  if (textScale >= 1.3) return 1;
  if (width <= AppBreakpoints.phone) return 2;
  if (width <= AppBreakpoints.tablet) return 3;
  return 4;
}

/// Filled icon for a home tile. Presentation only; the drawer keeps
/// [sectionIcon].
IconData homeTileIcon(SectionKey section) => switch (section) {
  SectionKey.customers => Icons.person,
  SectionKey.collections => Icons.payments,
  SectionKey.companies => Icons.apartment,
  SectionKey.libyanDeposits => Icons.account_balance_wallet,
  SectionKey.egyptianDeposits => Icons.currency_exchange,
  SectionKey.masraweya => Icons.menu_book,
  SectionKey.purchases => Icons.shopping_bag,
  SectionKey.treasury => Icons.account_balance,
  SectionKey.reports => Icons.insights,
};

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  static const screenKey = Key('home-dashboard');
  static const retryKey = Key('home-retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final dashboard = ref.watch(homeDashboardProvider);
    final fromFallback = ref.watch(homeLoadMetaProvider).fromFallback;
    final online = ref.watch(onlineProvider);
    final permissions = permissionsOf(ref);
    final money = ref.watch(apiLayerProvider).money;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    if (summary == null) {
      return const Center(child: Text(AppStrings.loading));
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeDashboardProvider);
        ref.invalidate(unreadCountProvider);
        ref.invalidate(unreadNotificationsCountProvider);
        await ref.read(homeDashboardProvider.future);
      },
      child: ListView(
        key: screenKey,
        padding: pagePadding(width),
        children: [
          // Ali's reference: one large tile per visible section, name only.
          // Same sections, order, permissions, and routes as before.
          if (summary.sections.isEmpty)
            const EmptyPane(message: AppStrings.noSections)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = homeTileColumns(
                  constraints.maxWidth,
                  textScale,
                );
                final tileWidth =
                    (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                    columns;
                return Wrap(
                  key: const Key('home-tile-grid'),
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final section in summary.sections)
                      SizedBox(
                        width: tileWidth,
                        child: HomeSectionTile(section: section),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          KeptData<HomeDto?>(
            value: dashboard,
            resetKey: 'home',
            retryKey: retryKey,
            onRetry: online
                ? () => ref.invalidate(homeDashboardProvider)
                : null,
            messageOf: (_) => AppStrings.homeError,
            loading: const SkeletonBox(
              key: HomeShell.homeLoadingKey,
              height: 88,
            ),
            builder: (home) {
              if (home == null) return const SizedBox.shrink();
              final cards = _visibleCards(home, permissions);
              final debts = _visibleDebts(home, permissions);
              final showAllSections = homeShowAllSections([
                for (final debt in debts) debt.section,
              ], permissions);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fromFallback)
                    Card(
                      key: const Key('home-fallback-banner'),
                      color: theme.colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: Text(
                          AppStrings.homeFallbackNote,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  if (home.businessDate != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      home.businessDate!,
                      key: const Key('home-business-date'),
                    ),
                  ],
                  if (home.generatedAt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${AppStrings.updatedAt} ${formatIsoDate(home.generatedAt)}',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.homeCardsTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (cards.isEmpty)
                    const EmptyPane(message: AppStrings.noSummaries)
                  else
                    LayoutBuilder(
                      builder: (context, constraints) => _SummaryGrid(
                        cards: cards,
                        money: money,
                        width: constraints.maxWidth,
                        columns: homeCardColumns(width, textScale),
                      ),
                    ),
                  if (home.oldDebts != null &&
                      (showAllSections.isNotEmpty ||
                          permissions.canRead(SectionKey.customers) ||
                          permissions.canRead(SectionKey.companies))) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.oldDebtsTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (debts.isEmpty)
                      const EmptyPane(message: AppStrings.emptyTicker)
                    else
                      for (final section in showAllSections) ...[
                        Text(
                          sectionLabel(sectionKeyFor(section)!),
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        for (final debt in debts)
                          if (debt.section == section)
                            _DebtRow(debt: debt, money: money),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            key: Key('show-all-$section'),
                            onPressed: () {
                              final path = homeShowAllPath(
                                section,
                                permissions,
                              );
                              if (path != null) context.go(path);
                            },
                            child: const Text(AppStrings.showAll),
                          ),
                        ),
                      ],
                  ],
                ],
              );
            },
          ),
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
                    onPressed: online
                        ? () => context.go(actionPath(action))
                        : null,
                    child: Text(actionLabel(action)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }

  List<HomeSummaryDto> _visibleCards(
    HomeDto home,
    PermissionService permissions,
  ) {
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
            width: ((width - AppSpacing.md * (columns - 1)) / columns).clamp(
              96,
              width,
            ),
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
    final units = card.valueUnits;
    final value = units != null && units.isInvalid
        ? MoneyValue.invalidLabel
        : card.currency != null
        ? money.formatOrDash(units, card.currency!)
        : (units == null || !units.isValid
              ? AppStrings.dash
              : money.formatNumber(units.units!));
    final status = reportStatusLabel(card.status);
    final theme = Theme.of(context);
    return Card(
      key: HomeShell.summaryKey(card.key),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            MoneyText(
              value,
              style: context.textExtras.amountLarge.copyWith(color: tone),
            ),
            if (status != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ReportStatusChip(status: card.status),
            ],
            if (card.note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(card.note!, style: theme.textTheme.bodySmall),
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
    final colors = context.statusColors;
    final amount = debt.currency == null
        ? AppStrings.dash
        : money.formatOrDash(debt.balanceUnits, debt.currency!);
    final width = MediaQuery.sizeOf(context).width;
    final theme = Theme.of(context);
    final flat = useFlatAgeCard(width, theme.brightness);
    final colored = visual.colored;
    final serverLabel = debt.ageStatusLabel?.trim();
    final age = (serverLabel != null && serverLabel.isNotEmpty)
        ? debt.ageStatusLabel
        : (debt.debtAgeDays != null ? sinceDays(debt.debtAgeDays) : null);
    final fg = colored ? colors.onStatus : theme.colorScheme.onSurface;
    final accent = colored
        ? (visual.accent ?? colors.onStatus)
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Material(
        key: Key('old-debt-${debt.id}'),
        color: colored
            ? (flat ? visual.flat : colors.neutralCard)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: colored && !flat ? visual.gradient : null,
            color: colored && flat ? visual.flat : null,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: colored
                  ? colors.onStatus.withValues(alpha: 0.2)
                  : theme.colorScheme.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.name, style: cairo(16, 800, color: fg)),
                MoneyText(
                  amount,
                  style: context.textExtras.amountLarge.copyWith(color: fg),
                ),
                if (age != null)
                  Text(
                    age,
                    key: Key('old-debt-age-${debt.id}'),
                    style: cairo(11, 500, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Deep blue tile with a gold bottom edge, a gold icon, and the white name.
class HomeSectionTile extends StatelessWidget {
  const HomeSectionTile({required this.section, super.key});

  final SectionKey section;

  static const _top = Color(0xFF1E3F9A);
  static const _bottom = Color(0xFF0B2468);
  static const _edge = Color(0xFFF2B705);
  static const _icon = Color(0xFFFFC928);

  @override
  Widget build(BuildContext context) {
    final label = sectionLabel(section);
    final radius = BorderRadius.circular(AppRadii.xxl);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: _edge,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        // The gold shows only along the bottom edge.
        padding: const EdgeInsetsDirectional.only(bottom: 4),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_top, _bottom],
              ),
            ),
            child: InkWell(
              key: HomeShell.sectionKey(section),
              onTap: () => context.go(sectionPath(section)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(homeTileIcon(section), size: 40, color: _icon),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        label,
                        key: Key('home-tile-label-${section.key}'),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: cairo(16, 800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
