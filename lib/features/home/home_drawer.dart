import 'package:flutter/material.dart';

import '../../models/home_summary.dart';
import '../../ui/bars_style.dart';
import '../../ui/section_labels.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import 'home_shell.dart';

const _sectionsTitle = 'الأقسام';

/// Phone drawer for bar options 1-5. Same items, order, targets and
/// callbacks as the old list; only the look differs.
class StyledDrawer extends StatelessWidget {
  const StyledDrawer({
    required this.items,
    required this.selected,
    required this.summary,
    required this.dark,
    required this.onSelect,
    required this.onToggleTheme,
    super.key,
  });

  final List<NavItem> items;
  final int selected;
  final HomeSummary summary;
  final bool dark;
  final ValueChanged<NavItem> onSelect;
  final VoidCallback onToggleTheme;

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
                children: [header, ...groups, const SizedBox(height: 12)],
              ),
            ),
          ),
          SafeArea(top: false, child: _themeRow(context, palette)),
        ],
      ),
    );
  }

  // ---- header -------------------------------------------------------------

  Widget _brand(BuildContext context, {Color? org}) {
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
          style: cairo(12, 600, color: org ?? colors.sidebarMuted),
        ),
      ],
    );
  }

  String get _initial {
    final name = summary.displayName.trim();
    return name.isEmpty ? '؟' : name.characters.first;
  }

  Widget _avatar({double size = 44, bool ring = false}) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kBrandBlue, kBrandNavy],
      ),
      border: Border.all(color: kBrandGold, width: ring ? 2 : 1.5),
    ),
    child: Text(
      _initial,
      style: cairo(size * 0.42, 800, color: kBrandGoldIcon),
    ),
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

  Widget _header(BuildContext context, _Palette p) {
    final top = MediaQuery.paddingOf(context).top;
    final colors = context.appColors;
    final sidebar = context.sidebarPalette;
    switch (kBarsStyle) {
      case 1:
      case 3:
        // Blue/gold card like the home tiles.
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12, top + 12, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: kBrandGold,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsetsDirectional.only(bottom: 3),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kBrandBlue, kBrandNavy],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brand(context, org: const Color(0xFFC9D6F5)),
                  const SizedBox(height: 14),
                  _identity(name: Colors.white, role: const Color(0xFFC9D6F5)),
                ],
              ),
            ),
          ),
        );
      case 2:
        // Brand band, then an inset identity card.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colors.sidebarBg,
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
      case 4:
        return Container(
          decoration: BoxDecoration(
            color: colors.sidebarBg,
            border: const Border(
              bottom: BorderSide(color: kBrandGold, width: 2),
            ),
          ),
          padding: EdgeInsetsDirectional.fromSTEB(16, top + 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _brand(context),
              const SizedBox(height: 14),
              _identity(name: sidebar.shine, role: colors.sidebarMuted),
            ],
          ),
        );
      default: // 5
        return Container(
          padding: EdgeInsetsDirectional.fromSTEB(16, top + 16, 16, 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x33F2B705), width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _brand(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  _avatar(size: 52, ring: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cairo(16, 800, color: sidebar.shine),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: const Color(0x99F2B705)),
                          ),
                          child: Text(
                            roleLabel(summary.role),
                            style: cairo(12, 700, color: sidebar.bright),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  // ---- groups -------------------------------------------------------------

  Widget _groupTitle(String text, _Palette p) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(28, 14, 28, 6),
    child: Text(text, style: cairo(12, 700, color: p.muted)),
  );

  Widget _group(BuildContext context, _Palette p, List<int> indexes) {
    final rows = [for (final i in indexes) _row(context, p, i)];
    if (kBarsStyle == 2) {
      // Inset grouped card with hairlines.
      return Padding(
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
    }
    if (kBarsStyle == 4) {
      return Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                endIndent: 16,
                color: p.line,
              ),
            rows[r],
          ],
        ],
      );
    }
    return Column(children: rows);
  }

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
    switch (kBarsStyle) {
      case 2:
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
      case 4:
        return Material(
          color: on ? p.selectedBg : Colors.transparent,
          child: InkWell(
            onTap: tap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 52,
                    color: on ? kBrandGold : Colors.transparent,
                  ),
                  const SizedBox(width: 17),
                  Icon(
                    item.icon,
                    size: 22,
                    color: on ? p.selectedInk : p.muted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: title),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      case 3:
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          child: Material(
            color: on ? p.selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: tap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 26,
                      decoration: BoxDecoration(
                        color: on ? kBrandGold : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on
                            ? const Color(0x33F2B705)
                            : const Color(0x14FFFFFF),
                      ),
                      child: Icon(
                        item.icon,
                        size: 19,
                        color: on ? p.selectedInk : p.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: title),
                  ],
                ),
              ),
            ),
          ),
        );
      default: // 1 and 5: pill rows
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 1,
          ),
          child: Material(
            color: on ? p.selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: tap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: on ? p.selectedInk : p.muted,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: title),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _themeRow(BuildContext context, _Palette p) {
    final label = dark ? AppStrings.themeLight : AppStrings.themeDark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 12),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(kBarsStyle == 2 ? 12 : 16),
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
    required this.selectedBg,
    required this.selectedInk,
    required this.line,
  });

  final Color background;
  final Color card;
  final Color ink;
  final Color muted;
  final Color selectedBg;
  final Color selectedInk;
  final Color line;

  static _Palette of(BuildContext context, bool dark) {
    final colors = context.appColors;
    final sidebar = context.sidebarPalette;
    switch (kBarsStyle) {
      case 1:
        return dark
            ? const _Palette(
                background: Color(0xFF151C27),
                card: Color(0xFF1E2735),
                ink: Color(0xFFE6EAF2),
                muted: Color(0xFFA7B1C2),
                selectedBg: Color(0xFF2A3A66),
                selectedInk: Colors.white,
                line: Color(0x1FFFFFFF),
              )
            : const _Palette(
                background: Color(0xFFF7F9FC),
                card: Color(0xFFEDF1F8),
                ink: Color(0xFF1B2230),
                muted: Color(0xFF5B6475),
                selectedBg: Color(0xFFD9E2F6),
                selectedInk: kBrandNavy,
                line: Color(0x14000000),
              );
      case 2:
        return dark
            ? const _Palette(
                background: Color(0xFF000000),
                card: Color(0xFF1C1C1E),
                ink: Color(0xFFF2F2F7),
                muted: Color(0xFF8E8E93),
                selectedBg: Color(0xFF2C2C2E),
                selectedInk: kBrandGoldIcon,
                line: Color(0x33FFFFFF),
              )
            : const _Palette(
                background: Color(0xFFF2F2F7),
                card: Colors.white,
                ink: Color(0xFF1C1C1E),
                muted: Color(0xFF8A8A8F),
                selectedBg: Color(0xFFEFF3FB),
                selectedInk: kBrandBlue,
                line: Color(0x22000000),
              );
      case 4:
        return dark
            ? const _Palette(
                background: Color(0xFF121821),
                card: Color(0xFF1A222D),
                ink: Color(0xFFE6EAF2),
                muted: Color(0xFF8C96A8),
                selectedBg: Color(0x14FFC928),
                selectedInk: kBrandGoldIcon,
                line: Color(0x1FFFFFFF),
              )
            : const _Palette(
                background: Colors.white,
                card: Color(0xFFF4F6FA),
                ink: Color(0xFF1B2230),
                muted: Color(0xFF6B7280),
                selectedBg: Color(0x0D1E3F9A),
                selectedInk: kBrandBlue,
                line: Color(0x14000000),
              );
      default: // 3 and 5: brand dark
        return _Palette(
          background: colors.sidebarBg,
          card: const Color(0x14FFFFFF),
          ink: sidebar.shine,
          muted: colors.sidebarMuted,
          selectedBg: kBarsStyle == 5 ? kBrandGold : const Color(0x24F2B705),
          selectedInk: kBarsStyle == 5 ? kBrandNavy : sidebar.bright,
          line: const Color(0x22FFFFFF),
        );
    }
  }
}
