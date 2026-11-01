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
          label: sectionLabel(section),
          path: sectionPath(section),
        ),
      if (showsSettingsEntry(permissions))
        const HomeTile(
          tileKey: settingsTileKey,
          labelKey: Key('home-tile-label-settings'),
          icon: Icons.settings,
          label: AppStrings.settings,
          path: '/settings',
        ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeDashboardProvider);
        ref.invalidate(unreadCountProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      },
      child: ListView(
        key: screenKey,
        padding: pagePadding(width),
        children: [
          const SizedBox(height: AppSpacing.sm),
          if (summary.sections.isEmpty)
            const EmptyPane(message: AppStrings.noSections),
          if (tiles.isNotEmpty)
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
                    for (final tile in tiles)
                      SizedBox(width: tileWidth, child: tile),
                  ],
                );
              },
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Deep blue tile with a gold bottom edge, a gold icon, and the white name.
class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.tileKey,
    required this.labelKey,
    required this.icon,
    required this.label,
    required this.path,
    super.key,
  });

  final Key tileKey;
  final Key labelKey;
  final IconData icon;
  final String label;
  final String path;

  static const _top = Color(0xFF1E3F9A);
  static const _bottom = Color(0xFF0B2468);
  static const _edge = Color(0xFFF2B705);
  static const _icon = Color(0xFFFFC928);

  @override
  Widget build(BuildContext context) {
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
                      Icon(icon, size: 40, color: _icon),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        label,
                        key: labelKey,
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
