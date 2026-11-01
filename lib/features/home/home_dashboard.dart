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

    final pad = pagePadding(width);
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
                if (tiles.isNotEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) => HomeFillGrid(
                        tiles: tiles,
                        columns: homeTileColumns(
                          constraints.maxWidth,
                          textScale,
                        ),
                      ),
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

const _tileTop = Color(0xFF1E3F9A);
const _tileBottom = Color(0xFF0B2468);
const _tileEdge = Color(0xFFF2B705);
const _tileGold = Color(0xFFFFC928);

/// Blue/gold card frame shared by the home extras (same look as [HomeTile]).
class _BlueCard extends StatelessWidget {
  const _BlueCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.xxl);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: _tileEdge,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_tileTop, _tileBottom],
          ),
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: child,
      ),
    );
  }
}

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];
const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Today in Africa/Tripoli (UTC+2 all year, no DST), Arabic names with
/// Latin digits like the rest of the app, e.g. «الأحد 1 نوفمبر 2026».
String tripoliTodayLabel([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 2));
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} ${t.year}';
}

/// Option 1: «مرحبًا، name» and today's date. Device clock only.
class HomeWelcomeCard extends StatelessWidget {
  const HomeWelcomeCard({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return _BlueCard(
      child: Row(
        children: [
          const Icon(Icons.waving_hand, color: _tileGold, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحبًا، $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(18, 800, color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  tripoliTodayLabel(),
                  style: cairo(13, 600, color: _tileGold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Option 2: text wordmark (no logo files exist), gold icon in a blue badge.
class HomeBrandBanner extends StatelessWidget {
  const HomeBrandBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_tileTop, _tileBottom],
              ),
              border: Border.fromBorderSide(
                BorderSide(color: _tileEdge, width: 2),
              ),
            ),
            child: const Icon(Icons.receipt_long, color: _tileGold, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.appTitle,
                  style: cairo(
                    26,
                    900,
                    color: dark ? Colors.white : _tileBottom,
                  ),
                ),
                Container(height: 3, width: 64, color: _tileEdge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Option 3: looks like a field, opens the existing /search screen (the
/// same route as the app bar search icon). No search logic of its own.
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.pill);
    return Semantics(
      button: true,
      label: 'ابحث عن عميل',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: _tileEdge, width: 1.5),
        ),
        child: InkWell(
          key: const Key('home-search-field'),
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          onTap: () => context.go('/search'),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: _tileTop),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'ابحث عن عميل',
                    style: cairo(15, 600, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Option 4: rows share the free height evenly; each tile keeps its own
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

/// Option 5: the build name Flutter injects from pubspec (FLUTTER_BUILD_NAME).
/// No new dependency. Hidden when the define is missing.
class HomeVersionFooter extends StatelessWidget {
  const HomeVersionFooter({super.key});

  static const _version = String.fromEnvironment('FLUTTER_BUILD_NAME');

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 14, color: _tileEdge),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${AppStrings.appTitle} • الإصدار $_version',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
