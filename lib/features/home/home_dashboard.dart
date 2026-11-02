import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/home_summary.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
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

/// Tile tint per section, as in concepts 1 and 3: blue, violet, green.
/// Presentation only.
Color homeTileTint(SectionKey? section, AppLook look) => switch (section) {
  SectionKey.customers ||
  SectionKey.libyanDeposits ||
  SectionKey.treasury => look.accent,
  SectionKey.companies ||
  SectionKey.purchases ||
  SectionKey.egyptianDeposits => look.violet,
  SectionKey.collections ||
  SectionKey.masraweya ||
  SectionKey.reports => look.success,
  null => look.muted,
};

/// Home: the icon grid only (Ali, 2026-11-01). One tile per visible section,
/// name only, then «الإعدادات» for whoever can open settings.
///
/// The section list, its order, and its visibility come from [HomeSummary]
/// (the permission service), unchanged. Each tile opens the same route as
/// before. The settings tile uses [showsSettingsEntry], the rule the side
/// navigation and «المزيد» already use.
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  static const screenKey = Key('home-dashboard');
  static const retryKey = Key('home-retry');
  static const settingsTileKey = Key('home-tile-settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final permissions = permissionsOf(ref);
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    if (summary == null) {
      return const Center(child: Text(AppStrings.loading));
    }
    final tiles = <Widget>[
      for (final section in summary.sections)
        HomeTile(
          tileKey: HomeShell.sectionKey(section),
          labelKey: Key('home-tile-label-${section.key}'),
          icon: homeTileIcon(section),
          tint: homeTileTint(section, context.look),
          label: sectionLabel(section),
          path: sectionPath(section),
        ),
      if (showsSettingsEntry(permissions))
        HomeTile(
          tileKey: settingsTileKey,
          labelKey: const Key('home-tile-label-settings'),
          icon: Icons.settings,
          tint: homeTileTint(null, context.look),
          label: AppStrings.settings,
          path: '/settings',
        ),
    ];

    final pad = pagePadding(width);
    final columns = homeTileColumns(width - pad.horizontal, textScale);
    final scroll = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeDashboardProvider);
        ref.invalidate(unreadCountProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      },
      child: CustomScrollView(
        key: screenKey,
        slivers: [
          SliverPadding(
            padding: pad,
            sliver: SliverMainAxisGroup(
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                if (summary.sections.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyPane(message: AppStrings.noSections),
                  ),
                // Option 4 (Ali, 2026-11-01): the rows share the free height.
                // Large text (one column) keeps natural tile heights and
                // scrolls, so a capped tile never clips its label.
                if (tiles.isNotEmpty && columns > 1)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    // No LayoutBuilder here: SliverFillRemaining measures
                    // intrinsics.
                    child: HomeFillGrid(tiles: tiles, columns: columns),
                  ),
                if (tiles.isNotEmpty && columns == 1)
                  SliverToBoxAdapter(
                    child: Column(
                      key: const Key('home-tile-grid'),
                      children: [
                        for (final tile in tiles)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.md,
                            ),
                            child: tile,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return scroll;
  }
}

/// Section tile: a tinted glass card (dark) or a white card with a soft
/// shadow (light), the icon in a tinted square, and the name in ink.
class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.tileKey,
    required this.labelKey,
    required this.icon,
    required this.tint,
    required this.label,
    required this.path,
    super.key,
  });

  final Key tileKey;
  final Key labelKey;
  final IconData icon;
  final Color tint;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final radius = BorderRadius.circular(AppRadii.xxl);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: look.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: look.tileFill(tint),
              border: Border.all(
                color: look.glass
                    ? Color.alphaBlend(
                        tint.withValues(alpha: 0.22),
                        look.cardBorder,
                      )
                    : look.cardBorder,
              ),
            ),
            child: InkWell(
              key: tileKey,
              onTap: () => context.go(path),
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
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: look.iconWell(tint),
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                        child: Icon(icon, size: 30, color: tint),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        label,
                        key: labelKey,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: cairo(16, 700, color: look.ink),
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

/// Rows share the free height evenly; each tile keeps its own
/// minimum (so small screens scroll) and is capped at 190.
class HomeFillGrid extends StatelessWidget {
  const HomeFillGrid({required this.tiles, required this.columns, super.key});

  final List<Widget> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.md));
      rows.add(
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: i + c < tiles.length
                        ? tiles[i + c]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Column(
        key: const Key('home-tile-grid'),
        mainAxisAlignment: MainAxisAlignment.start,
        children: rows,
      ),
    );
  }
}
