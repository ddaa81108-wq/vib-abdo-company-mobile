import 'package:flutter/material.dart';

import '../../models/home_summary.dart';
import '../../ui/bars_style.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import 'home_shell.dart';

const _sectionsTitle = 'الأقسام';

/// Phone drawer: grouped inset cards (Ali's pick, 2026-11-01). Same items,
/// order, targets and callbacks as the old list; only the look differs.
class StyledDrawer extends StatelessWidget {
  const StyledDrawer({
    required this.items,
    required this.selected,
    required this.summary,
    required this.dark,
    required this.onSelect,
    required this.onToggleTheme,
    required this.onLogout,
    super.key,
  });

  static const logoutKey = Key('drawer-logout');

  final List<NavItem> items;
  final int selected;
  final HomeSummary summary;
  final bool dark;
  final ValueChanged<NavItem> onSelect;
  final VoidCallback onToggleTheme;

  /// The app's existing logout request (it asks to confirm first).
  final VoidCallback onLogout;

  bool _isAccount(NavItem item) =>
      item.id == 'settings' || item.id == 'account';

  @override
  Widget build(BuildContext context) {
    final main = <int>[];
    final account = <int>[];
    for (var i = 0; i < items.length; i++) {
      (_isAccount(items[i]) ? account : main).add(i);
    }
    final palette = _Palette.of(context, dark);
    final header = _header(context, palette);
    final groups = <Widget>[
      _groupTitle(_sectionsTitle, palette),
      _group(context, palette, main),
      if (account.isNotEmpty) ...[
        _groupTitle(AppStrings.signedInAs, palette),
        _group(context, palette, account),
      ],
    ];
    // Footer: the theme row, then logout last. Pinned at the bottom on
    // normal phones; with large text or a short screen it scrolls at the
    // end of the list instead, so nothing is hidden or overlapped.
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _themeRow(context, palette),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
          child: Material(
            color: palette.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: _logoutRow(palette),
          ),
        ),
      ],
    );
    final pinned =
        MediaQuery.textScalerOf(context).scale(1) <= 1.3 &&
        MediaQuery.sizeOf(context).height >= 560;
    return Material(
      color: palette.background,
      child: Column(
        children: [
          // A few rows only: build them all (no lazy list), so every
          // destination exists for screen readers and tests.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  ...groups,
                  const SizedBox(height: 12),
                  if (!pinned) SafeArea(top: false, child: footer),
                ],
              ),
            ),
          ),
          if (pinned) SafeArea(top: false, child: footer),
        ],
      ),
    );
  }

  // ---- header -------------------------------------------------------------

  Widget _brand(BuildContext context) {
    final sidebar = context.sidebarPalette;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.brandWord,
          style: cairo(20, 800, color: sidebar.bright),
        ),
        Text(
          AppStrings.organization,
          style: cairo(12, 600, color: colors.sidebarMuted),
        ),
      ],
    );
  }

  String get _initial {
    final name = summary.displayName.trim();
    return name.isEmpty ? '؟' : name.characters.first;
  }

  Widget _avatar() => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kBrandBlue, kBrandNavy],
      ),
      border: Border.all(color: kBrandGold, width: 1.5),
    ),
    child: Text(_initial, style: cairo(18.5, 800, color: kBrandGoldIcon)),
  );

  Widget _identity({required Color name, required Color role}) => Row(
    children: [
      _avatar(),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairo(15, 800, color: name),
            ),
            Text(
              roleLabel(summary.role),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cairo(12.5, 600, color: role),
            ),
          ],
        ),
      ),
    ],
  );

  // Brand band, then an inset identity card.
  Widget _header(BuildContext context, _Palette p) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: context.appColors.sidebarBg,
          padding: EdgeInsetsDirectional.fromSTEB(16, top + 14, 16, 14),
          child: _brand(context),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _identity(name: p.ink, role: p.muted),
          ),
        ),
      ],
    );
  }

  // ---- groups -------------------------------------------------------------

  Widget _groupTitle(String text, _Palette p) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(28, 14, 28, 6),
    child: Text(text, style: cairo(12, 700, color: p.muted)),
  );

  Widget _group(BuildContext context, _Palette p, List<int> indexes) =>
      _card(p, [for (final i in indexes) _row(context, p, i)]);

  // Inset grouped card with hairlines.
  Widget _card(_Palette p, List<Widget> rows) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 56),
                child: Divider(height: 0.5, thickness: 0.5, color: p.line),
              ),
            rows[r],
          ],
        ],
      ),
    ),
  );

  /// Same size as the other rows: icon square and label, in red.
  Widget _logoutRow(_Palette p) => Semantics(
    button: true,
    label: AppStrings.logout,
    child: InkWell(
      key: logoutKey,
      onTap: onLogout,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        // The label is on the Semantics above; the tap stays on the InkWell.
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: p.danger,
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    AppStrings.logout,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairo(14.5, 700, color: p.dangerInk),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _row(BuildContext context, _Palette p, int index) {
    final item = items[index];
    final on = index == selected;
    final title = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: cairo(14.5, on ? 800 : 600, color: on ? p.selectedInk : p.ink),
    );
    void tap() => onSelect(item);
    return InkWell(
      onTap: tap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [kBrandBlue, kBrandNavy],
                  ),
                ),
                child: Icon(item.icon, size: 18, color: kBrandGoldIcon),
              ),
              const SizedBox(width: 14),
              Expanded(child: title),
              Icon(
                on ? Icons.check : Icons.chevron_right,
                size: on ? 20 : 18,
                color: on ? p.selectedInk : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeRow(BuildContext context, _Palette p) {
    final label = dark ? AppStrings.themeLight : AppStrings.themeDark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 8),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggleTheme,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: p.ink,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: cairo(14, 600, color: p.ink)),
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

class _Palette {
  const _Palette({
    required this.background,
    required this.card,
    required this.ink,
    required this.muted,
    required this.selectedInk,
    required this.line,
    required this.danger,
    required this.dangerInk,
  });

  final Color background;
  final Color card;
  final Color ink;
  final Color muted;
  final Color selectedInk;
  final Color line;

  /// Logout icon square and label.
  final Color danger;
  final Color dangerInk;

  static _Palette of(BuildContext context, bool dark) => dark
      ? const _Palette(
          background: Color(0xFF000000),
          card: Color(0xFF1C1C1E),
          ink: Color(0xFFF2F2F7),
          muted: Color(0xFF8E8E93),
          selectedInk: kBrandGoldIcon,
          line: Color(0x33FFFFFF),
          danger: Color(0xFFD93A3A),
          dangerInk: Color(0xFFFF7A7A),
        )
      : const _Palette(
          background: Color(0xFFF2F2F7),
          card: Colors.white,
          ink: Color(0xFF1C1C1E),
          muted: Color(0xFF8A8A8F),
          selectedInk: kBrandBlue,
          line: Color(0x22000000),
          danger: Color(0xFFD93A3A),
          dangerInk: Color(0xFFC62828),
        );
}
