import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import 'home_design_options.dart';
import 'home_shell.dart';
import 'home_layout.dart';
import 'home_tile.dart';
import 'home_grid.dart';
export 'home_layout.dart';
export 'home_tile.dart' show HomeTile;

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
          required String label,
          required String path,
        }) {
          return HomeTile(
            tileKey: tileKey,
            labelKey: labelKey,
            mark: mark,
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
              label: sectionLabel(section),
              path: sectionPath(section),
            ),
          if (showsSettingsEntry(permissions))
            tileFor(
              tileKey: settingsTileKey,
              labelKey: const Key('home-tile-label-settings'),
              mark: HomeIconMark.settings(size: icon),
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
