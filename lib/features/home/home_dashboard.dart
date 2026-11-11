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
import 'home_design_options.dart';
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

/// Glossy tile finish per section, as in concepts 1 and 3: blue, violet,
/// green. Presentation only.
Gloss homeTileGloss(SectionKey? section, AppLook look) => switch (section) {
  SectionKey.customers ||
  SectionKey.libyanDeposits ||
  SectionKey.treasury => look.glossBlue,
  SectionKey.companies ||
  SectionKey.purchases ||
  SectionKey.egyptianDeposits => look.glossViolet,
  SectionKey.collections ||
  SectionKey.masraweya ||
  SectionKey.reports => look.glossGreen,
  null => look.glossGrey,
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
    final pad = pagePadding(width);
    final columns = homeTileColumns(width - pad.horizontal, textScale);
    Future<void> refresh() async {
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final look = context.look;
        final count =
            summary.sections.length + (showsSettingsEntry(permissions) ? 1 : 0);
        final rows = count == 0 ? 0 : (count / columns).ceil();
        const gap = 4.0;
        final budget = constraints.maxHeight - pad.vertical - AppSpacing.xs;
        final raw = rows == 0 ? 0.0 : (budget - gap * (rows - 1)) / rows;
        // Text scale 1 shares the free height so every tile is on screen.
        // A short leftover, or large text, keeps a natural tile and scrolls.
        final fit = columns > 1 && textScale < 1.3 && raw >= 48;
        final rowHeight = fit ? raw.clamp(48.0, 148.0) : null;
        final icon = rowHeight == null
            ? 48.0
            : (rowHeight * 0.40).clamp(26.0, 52.0);
        final font = rowHeight == null
            ? 15.0
            : (rowHeight * 0.145).clamp(11.0, 14.0);
        final labelGap = rowHeight == null
            ? AppSpacing.sm
            : (rowHeight * 0.05).clamp(2.0, 6.0);

        HomeTile tileFor({
          required Key tileKey,
          required Key labelKey,
          required Widget mark,
          required Gloss gloss,
          required String label,
          required String path,
        }) {
          return HomeTile(
            tileKey: tileKey,
            labelKey: labelKey,
            mark: mark,
            gloss: gloss,
            label: label,
            path: path,
            fontSize: font,
            gap: labelGap,
          );
        }

        final tiles = <Widget>[
          for (final section in summary.sections)
            tileFor(
              tileKey: HomeShell.sectionKey(section),
              labelKey: Key('home-tile-label-${section.key}'),
              mark: HomeIconMark(section: section, size: icon),
              gloss: homeTileGloss(section, look),
              label: sectionLabel(section),
              path: sectionPath(section),
            ),
          if (showsSettingsEntry(permissions))
            tileFor(
              tileKey: settingsTileKey,
              labelKey: const Key('home-tile-label-settings'),
              mark: HomeIconMark.settings(size: icon),
              gloss: homeTileGloss(null, look),
              label: AppStrings.settings,
              path: '/settings',
            ),
        ];

        final grid = tiles.isEmpty
            ? const EmptyPane(message: AppStrings.noSections)
            : fit
            ? HomeFillGrid(
                tiles: tiles,
                columns: columns,
                rowHeight: rowHeight!,
                gap: gap,
              )
            : Column(
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
              );

        return RefreshIndicator(
          onRefresh: refresh,
          child: SingleChildScrollView(
            key: screenKey,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(padding: pad, child: grid),
            ),
          ),
        );
      },
    );
  }
}

/// Section tile: a glossy card in its section colour (vivid in dark, soft
/// in light) with a sheen, bright border and glow; the icon sits in a
/// translucent square.
class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.tileKey,
    required this.labelKey,
    required this.mark,
    required this.gloss,
    required this.label,
    required this.path,
    this.fontSize = 15,
    this.gap = AppSpacing.sm,
    super.key,
  });

  final Key tileKey;
  final Key labelKey;
  final Widget mark;
  final Gloss gloss;
  final String label;
  final String path;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.xxl);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: gloss.glowShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: gloss.decoration(radius),
            child: InkWell(
              key: tileKey,
              onTap: () => context.go(path),
              child: GlossSheen(
                gloss: gloss,
                radius: radius,
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          mark,
                          SizedBox(height: gap),
                          Text(
                            label,
                            key: labelKey,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: cairo(fontSize, 700, color: gloss.ink),
                          ),
                        ],
                      ),
                    ),
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

/// Equal rows that share the free height. Each cell is at least 48dp.
class HomeFillGrid extends StatelessWidget {
  const HomeFillGrid({
    required this.tiles,
    required this.columns,
    required this.rowHeight,
    required this.gap,
    super.key,
  });

  final List<Widget> tiles;
  final int columns;
  final double rowHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: i + c < tiles.length
                      ? tiles[i + c]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      key: const Key('home-tile-grid'),
      mainAxisAlignment: MainAxisAlignment.start,
      children: rows,
    );
  }
}
