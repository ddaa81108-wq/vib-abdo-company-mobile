import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/home_summary.dart';
import '../../notifications/unread_badge.dart';
import '../../state/notification_providers.dart';
import '../../state/session_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

class NavItem {
  const NavItem({required this.id, required this.label, required this.icon, required this.path});

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

  static Key sectionKey(SectionKey section) => Key('section-${section.key}');
  static Key writeKey(SectionKey section) => Key('write-${section.key}');
  static Key actionKey(ManagementAction action) => Key('action-${action.proposedCode}');
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
                tooltip: _collapsed ? AppStrings.showSidebar : AppStrings.hideSidebar,
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
            color: online ? context.appColors.success : Theme.of(context).colorScheme.error,
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
                    width: width >= AppBreakpoints.wide ? 300 : 260,
                    child: _NavList(
                      items: items,
                      selected: selected,
                      summary: summary,
                      showIdentity: true,
                      dark: dark,
                      onSelect: (item) => context.go(item.path),
                    ),
                  )
                else if (rail)
                  _Rail(
                    items: items,
                    selected: selected,
                    summary: summary,
                    dark: dark,
                    onSelect: (item) => context.go(item.path),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (showIdentityHere) IdentityBlock(summary: summary),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: phone ? _BottomBar(items: items, location: widget.location) : null,
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
          Text(
            summary.displayName,
            style: theme.textTheme.titleMedium,
          ),
          Text(roleLabel(summary.role), key: HomeShell.roleKey),
        ],
      ),
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
  });

  final List<NavItem> items;
  final int selected;
  final HomeSummary summary;
  final bool dark;
  final ValueChanged<NavItem> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.sidebarPalette;
    final rail = NavigationRail(
      extended: MediaQuery.sizeOf(context).width >= 720,
      minExtendedWidth: 220,
      selectedIndex: selected,
      onDestinationSelected: (index) => onSelect(items[index]),
      leading: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: palette.shine,
            displayColor: palette.shine,
          ),
        ),
        child: IdentityBlock(summary: summary),
      ),
      trailing: IconButton(
        tooltip: dark ? AppStrings.themeLight : AppStrings.themeDark,
        onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: rail),
          ),
        );
      },
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
    return Material(
      color: colors.sidebarBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                AppStrings.brandWord,
                style: cairo(20, 800, color: palette.base),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
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
              ListTile(
                selected: i == selected,
                selectedTileColor: palette.glowSoft,
                iconColor: i == selected ? palette.bright : colors.sidebarMuted,
                textColor: i == selected ? palette.bright : palette.shine,
                leading: Icon(items[i].icon),
                title: Text(items[i].label),
                onTap: () => onSelect(items[i]),
              ),
            ListTile(
              leading: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: palette.shine,
              ),
              title: Text(
                dark ? AppStrings.themeLight : AppStrings.themeDark,
                style: cairo(13, 600, color: palette.shine),
              ),
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.items, required this.location});

  final List<NavItem> items;
  final String location;

  @override
  Widget build(BuildContext context) {
    final sections = items.where((item) => item.id != 'home' && item.id != 'settings' && item.id != 'account');
    final head = sections.take(3).toList();
    final rest = sections.skip(3).toList();
    final tail = items.where((item) => item.id == 'settings' || item.id == 'account').toList();
    final tabs = [
      items.firstWhere((item) => item.id == 'home'),
      ...head,
      const NavItem(id: 'more', label: AppStrings.more, icon: Icons.more_horiz, path: ''),
    ];
    var selected = tabs.length - 1;
    for (var i = 0; i < head.length; i++) {
      if (_matches(head[i].path, location)) selected = i + 1;
    }
    if (_matches('/', location)) selected = 0;

    return NavigationBar(
      selectedIndex: selected,
      destinations: [
        for (final tab in tabs)
          NavigationDestination(icon: Icon(tab.icon), label: tab.label),
      ],
      onDestinationSelected: (index) {
        if (tabs[index].id == 'more') {
          showModalBottomSheet<void>(
            context: context,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in [...rest, ...tail])
                    ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(item.path);
                      },
                    ),
                ],
              ),
            ),
          );
          return;
        }
        context.go(tabs[index].path);
      },
    );
  }
}
