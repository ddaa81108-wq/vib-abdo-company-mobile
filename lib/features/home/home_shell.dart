import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/home_summary.dart';
import '../../notifications/unread_badge.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../settings/admin_destinations.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/soft_tile.dart';

class NavItem {
  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
  });

  final String id;
  final String label;
  final IconData icon;
  final String path;
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const shellKey = Key('home-shell');
  static const logoutKey = Key('logout-button');
  static const roleKey = Key('role-label');
  static const homeLoadingKey = Key('home-loading');
  static const menuKey = Key('open-menu');
  static const bottomBarKey = Key('phone-bottom-bar');
  static const railKey = Key('nav-rail');
  static const panelKey = Key('nav-panel');

  static Key sectionKey(SectionKey section) => Key('section-${section.key}');
  static Key writeKey(SectionKey section) => Key('write-${section.key}');
  static Key actionKey(ManagementAction action) =>
      Key('action-${action.proposedCode}');
  static Key summaryKey(String cardKey) => Key('summary-$cardKey');

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  var _collapsed = false;
  int? _seenUnread;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider);
    final unread = ref.watch(unreadCountProvider);
    final online = ref.watch(onlineProvider);
    final width = MediaQuery.sizeOf(context).width;
    final phone = AppBreakpoints.isPhone(width);
    final rail = AppBreakpoints.isRail(width);
    final panel = AppBreakpoints.isPanel(width);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;

    ref.listen<AsyncValue<int?>>(unreadCountProvider, (previous, next) {
      final count = next.asData?.value;
      if (count == null) return;
      final seen = _seenUnread;
      _seenUnread = count;
      if (seen != null && count > seen && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text(AppStrings.notifications),
          ),
        );
      }
    });

    if (summary == null) {
      return const Scaffold(
        key: HomeShell.shellKey,
        body: Center(child: Text(AppStrings.loading)),
      );
    }

    final permissions = permissionsOf(ref);
    final items = _items(summary, permissions);
    final selected = _selectedIndex(items, widget.location);
    final showIdentityHere = phone;
    final sidebar = context.sidebarPalette;
    final colors = context.appColors;

    return Scaffold(
      key: HomeShell.shellKey,
      drawer: phone
          ? Drawer(
              child: _NavList(
                items: items,
                selected: selected,
                summary: summary,
                showIdentity: false,
                dark: dark,
                onSelect: (item) {
                  Navigator.of(context).pop();
                  context.go(item.path);
                },
              ),
            )
          : null,
      appBar: AppBar(
        leading: phone
            ? Builder(
                builder: (barContext) => IconButton(
                  key: HomeShell.menuKey,
                  tooltip: AppStrings.menu,
                  onPressed: () => Scaffold.of(barContext).openDrawer(),
                  icon: const Icon(Icons.menu),
                ),
              )
            : panel
            ? IconButton(
                tooltip: _collapsed
                    ? AppStrings.showSidebar
                    : AppStrings.hideSidebar,
                onPressed: () => setState(() => _collapsed = !_collapsed),
                icon: Icon(_collapsed ? Icons.menu_open : Icons.menu),
              )
            : const SizedBox.shrink(),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(_title(widget.location)),
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.search,
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search),
          ),
          Icon(
            Icons.circle,
            size: 10,
            color: online
                ? context.appColors.success
                : Theme.of(context).colorScheme.error,
          ),
          UnreadBadge(
            count: unread.asData?.value,
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            key: HomeShell.logoutKey,
            tooltip: AppStrings.logout,
            onPressed: () => ref.read(sessionStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectionBanner(online: online),
          Expanded(
            child: Row(
              children: [
                if (panel && !_collapsed)
                  SizedBox(
                    width: math
                        .max(
                          width >= AppBreakpoints.wide ? 300.0 : 260.0,
                          200.0,
                        )
                        .clamp(200.0, width * 0.5),
                    child: _NavList(
                      key: HomeShell.panelKey,
                      items: items,
                      selected: selected,
                      summary: summary,
                      showIdentity: true,
                      dark: dark,
                      onSelect: (item) => context.go(item.path),
                    ),
                  )
                else if (rail)
                  SizedBox(
                    width: (200 * MediaQuery.textScalerOf(context).scale(1))
                        .clamp(188.0, width * 0.46),
                    child: _Rail(
                      key: HomeShell.railKey,
                      items: items,
                      selected: selected,
                      summary: summary,
                      dark: dark,
                      onSelect: (item) => context.go(item.path),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (showIdentityHere) _PhoneIdentity(summary: summary),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: phone
          ? _BottomBar(
              items: items,
              location: widget.location,
              indicator: sidebar.glowSoft,
              selectedColor: sidebar.bright,
              idleColor: colors.sidebarMuted,
              background: colors.sidebarBg,
            )
          : null,
    );
  }

  List<NavItem> _items(HomeSummary summary, PermissionService permissions) {
    return [
      const NavItem(
        id: 'home',
        label: AppStrings.homeTitle,
        icon: Icons.home_outlined,
        path: '/',
      ),
      for (final section in summary.sections)
        NavItem(
          id: section.key,
          label: sectionLabel(section),
          icon: sectionIcon(section),
          path: sectionPath(section),
        ),
      if (permissions.canViewFinancialLedger ||
          permissions.canDo(ManagementAction.settingsManage))
        const NavItem(
          id: 'settings',
          label: AppStrings.settings,
          icon: Icons.settings_outlined,
          path: '/settings',
        ),
      const NavItem(
        id: 'account',
        label: AppStrings.myAccount,
        icon: Icons.manage_accounts_outlined,
        path: '/account',
      ),
    ];
  }

  int _selectedIndex(List<NavItem> items, String location) {
    for (var i = 0; i < items.length; i++) {
      if (_matches(items[i].path, location)) return i;
    }
    return 0;
  }

  String _title(String location) {
    if (location == '/' || location.isEmpty) return AppStrings.homeTitle;
    if (location.startsWith('/notifications')) return AppStrings.notifications;
    final admin = adminDestinationFor(location);
    if (admin != null) return admin.title;
    if (location.startsWith('/settings')) return AppStrings.settings;
    if (location.startsWith('/account')) return AppStrings.myAccount;
    if (location.startsWith('/search')) return AppStrings.search;
    for (final section in SectionKey.values) {
      if (location.startsWith('/${section.key}')) return sectionLabel(section);
    }
    return AppStrings.appTitle;
  }
}

bool _matches(String path, String location) {
  if (path == '/') return location == '/';
  return location == path || location.startsWith('$path/');
}

class IdentityBlock extends StatelessWidget {
  const IdentityBlock({required this.summary, super.key});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.signedInAs, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(summary.displayName, style: theme.textTheme.titleMedium),
          Text(roleLabel(summary.role), key: HomeShell.roleKey),
        ],
      ),
    );
  }
}

/// Keeps the signed-in name readable without pushing the page off screen
/// when the text scale is large.
class _PhoneIdentity extends StatelessWidget {
  const _PhoneIdentity({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final block = IdentityBlock(summary: summary);
    if (scale <= 1.15) return block;
    final cap = (88 * scale).clamp(88.0, 160.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: cap),
      child: SingleChildScrollView(child: block),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.items,
    required this.selected,
    required this.summary,
    required this.dark,
    required this.onSelect,
    super.key,
  });

  final List<NavItem> items;
  final int selected;
  final HomeSummary summary;
  final bool dark;
  final ValueChanged<NavItem> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.sidebarPalette;
    final colors = context.appColors;
    return Material(
      color: colors.sidebarBg,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: palette.shine,
                      displayColor: palette.shine,
                    ),
                  ),
                  child: IdentityBlock(summary: summary),
                ),
                for (var i = 0; i < items.length; i++)
                  SoftTile(
                    key: Key('rail-${items[i].id}'),
                    selected: i == selected,
                    selectedColor: palette.glowSoft,
                    title: items[i].label,
                    titleColor: i == selected ? palette.bright : palette.shine,
                    iconColor: i == selected
                        ? palette.bright
                        : colors.sidebarMuted,
                    leading: Icon(items[i].icon),
                    onTap: () => onSelect(items[i]),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: dark ? AppStrings.themeLight : AppStrings.themeDark,
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: palette.shine,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavList extends ConsumerWidget {
  const _NavList({
    required this.items,
    required this.selected,
    required this.summary,
    required this.showIdentity,
    required this.dark,
    required this.onSelect,
    super.key,
  });

  final List<NavItem> items;
  final int selected;
  final HomeSummary summary;
  final bool showIdentity;
  final bool dark;
  final ValueChanged<NavItem> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.sidebarPalette;
    final colors = context.appColors;
    final themeTile = SoftTile(
      leading: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      title: dark ? AppStrings.themeLight : AppStrings.themeDark,
      titleColor: palette.shine,
      iconColor: palette.shine,
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
    );
    return Material(
      color: colors.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.md,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      AppStrings.brandWord,
                      style: cairo(20, 800, color: palette.base),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      AppStrings.organization,
                      style: cairo(12, 600, color: colors.sidebarMuted),
                    ),
                  ),
                  if (showIdentity)
                    Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.apply(
                          bodyColor: palette.shine,
                          displayColor: palette.shine,
                        ),
                      ),
                      child: IdentityBlock(summary: summary),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < items.length; i++)
                    SoftTile(
                      selected: i == selected,
                      selectedColor: palette.glowSoft,
                      title: items[i].label,
                      titleColor: i == selected
                          ? palette.bright
                          : palette.shine,
                      iconColor: i == selected
                          ? palette.bright
                          : colors.sidebarMuted,
                      leading: Icon(items[i].icon),
                      onTap: () => onSelect(items[i]),
                    ),
                ],
              ),
            ),
            themeTile,
          ],
        ),
      ),
    );
  }
}

/// Phone destinations in one row of equal slots. Labels wrap to two lines.
/// [tabs] always ends with the "more" item.
class PhoneBottomNav extends StatelessWidget {
  const PhoneBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.background,
    required this.indicator,
    required this.selectedColor,
    required this.idleColor,
    super.key,
  });

  final List<NavItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color background;
  final Color indicator;
  final Color selectedColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final safeIndex = tabs.isEmpty
        ? 0
        : selectedIndex.clamp(0, tabs.length - 1);
    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _PhoneTab(
                    key: Key('bottom-tab-${tabs[i].id}'),
                    item: tabs[i],
                    selected: i == safeIndex,
                    indicator: indicator,
                    selectedColor: selectedColor,
                    idleColor: idleColor,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneTab extends StatelessWidget {
  const _PhoneTab({
    required this.item,
    required this.selected,
    required this.indicator,
    required this.selectedColor,
    required this.idleColor,
    required this.onTap,
    super.key,
  });

  final NavItem item;
  final bool selected;
  final Color indicator;
  final Color selectedColor;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : idleColor;
    final style =
        Theme.of(context).navigationBarTheme.labelTextStyle?.resolve({}) ??
        cairo(11, 700, color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: selected ? indicator : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: 22),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.items,
    required this.location,
    required this.background,
    required this.indicator,
    required this.selectedColor,
    required this.idleColor,
  });

  final List<NavItem> items;
  final String location;
  final Color background;
  final Color indicator;
  final Color selectedColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final sections = items.where(
      (item) =>
          item.id != 'home' && item.id != 'settings' && item.id != 'account',
    );
    final head = sections.take(3).toList();
    final rest = sections.skip(3).toList();
    final tail = items
        .where((item) => item.id == 'settings' || item.id == 'account')
        .toList();
    final tabs = [
      items.firstWhere((item) => item.id == 'home'),
      ...head,
      const NavItem(
        id: 'more',
        label: AppStrings.more,
        icon: Icons.more_horiz,
        path: '',
      ),
    ];
    var selected = tabs.length - 1;
    for (var i = 0; i < head.length; i++) {
      if (_matches(head[i].path, location)) selected = i + 1;
    }
    if (_matches('/', location)) selected = 0;

    return PhoneBottomNav(
      key: HomeShell.bottomBarKey,
      tabs: tabs,
      selectedIndex: selected,
      background: background,
      indicator: indicator,
      selectedColor: selectedColor,
      idleColor: idleColor,
      onSelected: (index) {
        if (tabs[index].id == 'more') {
          final sheetItems = [...rest, ...tail];
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (sheetContext) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.45,
                minChildSize: 0.25,
                maxChildSize: 0.85,
                builder: (sheetBodyContext, controller) {
                  return ListView(
                    key: const Key('more-sheet'),
                    controller: controller,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          AppStrings.more,
                          style: Theme.of(sheetBodyContext)
                              .textTheme
                              .titleMedium,
                        ),
                      ),
                      for (final item in sheetItems)
                        SoftTile(
                          key: Key('more-${item.id}'),
                          leading: Icon(item.icon),
                          title: item.label,
                          trailing: forwardChevron(sheetBodyContext),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            context.go(item.path);
                          },
                        ),
                    ],
                  );
                },
              );
            },
          );
          return;
        }
        context.go(tabs[index].path);
      },
    );
  }
}
