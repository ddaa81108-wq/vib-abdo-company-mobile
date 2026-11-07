import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/section_kit.dart';
import '../../ui/widgets/soft_tile.dart';
import '../../ui/widgets/environment_badge.dart';
import '../../state/session_providers.dart';
import '../../ui/section_labels.dart';

/// Settings (Ali, 2026-11-04), arranged like the website: a green header
/// band with the signed-in owner, then equal glossy black cards with a gold
/// icon circle, title, one-line description and a gold open action. Only
/// screens the app really has get a card; the empty admin stand-ins
/// (التدقيق، التشغيل) are not linked.
class _SettingsLink {
  const _SettingsLink({
    required this.tileKey,
    required this.title,
    required this.note,
    required this.path,
    required this.icon,
  });

  final Key tileKey;
  final String title;
  final String note;
  final String path;
  final IconData icon;
}

class SettingsText {
  static const employeesNote =
      'حسابات الدخول وصلاحيات الأقسام. ليست حسابات التحصيل.';
  static const accountTitle = 'حسابي والمظهر';
  static const accountNote =
      'الوضع الليلي، صوت الإشعارات ونطقها، كلمة المرور، وتسجيل الخروج.';
  static const ledgerNote =
      'قراءة موحدة للقيود المالية من جميع الأقسام دون تعديل الأرصدة.';
  static const themeTitle = 'الوضع الليلي';
  static const themeNote = 'يُحفظ على هذا الجهاز فقط.';
  static const aboutTitle = 'حول التطبيق';
  static const environment = 'بيئة الخادم';
  static const production = 'الخادم الرسمي';
  static const ownerRole = 'المستخدم الحالي';
}

void _openLedger(BuildContext context) => context.go('/settings/ledger');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const screenKey = Key('screen-settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final manage = permissions.canDo(ManagementAction.settingsManage);
    final ledger = permissions.canViewFinancialLedger;
    if (!manage && !ledger) return const ForbiddenPane();
    final width = MediaQuery.sizeOf(context).width;
    final summary = ref.watch(homeSummaryProvider);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final links = <_SettingsLink>[
      if (manage)
        const _SettingsLink(
          tileKey: Key('settings-link-employees'),
          title: AppStrings.employeesTile,
          note: SettingsText.employeesNote,
          path: '/settings/users',
          icon: Icons.groups_outlined,
        ),
      if (manage)
        const _SettingsLink(
          tileKey: Key('settings-link-audit'),
          title: 'الأمان والسجل',
          note: 'الجلسة الحالية وسجل عمليات الخادم.',
          path: '/settings/audit',
          icon: Icons.fact_check_outlined,
        ),
      if (manage || ledger)
        const _SettingsLink(
          tileKey: Key('settings-link-development'),
          title: 'تطوير التطبيق',
          note: 'إصدار التطبيق وحالة الخادم، بلا محدّث عن بعد.',
          path: '/settings/development',
          icon: Icons.build_circle_outlined,
        ),
      const _SettingsLink(
        tileKey: Key('settings-link-account'),
        title: SettingsText.accountTitle,
        note: SettingsText.accountNote,
        path: '/account',
        icon: Icons.manage_accounts_outlined,
      ),
    ];
    Widget linkCard(_SettingsLink link) => _SettingsCard(
      key: link.tileKey,
      icon: link.icon,
      title: link.title,
      note: link.note,
      action: forwardChevron(context),
      onTap: () => context.go(link.path),
    );
    _SettingsLink? take(Key key) {
      for (final link in links) {
        if (link.tileKey == key) return link;
      }
      return null;
    }

    final account = take(const Key('settings-link-account'));
    final employees = take(const Key('settings-link-employees'));
    final audit = take(const Key('settings-link-audit'));
    final development = take(const Key('settings-link-development'));
    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(width),
        children: [
          _HeaderBand(
            name: summary?.displayName,
            role: summary == null ? null : roleLabel(summary.role),
          ),
          const _GroupLabel('الحساب'),
          if (account != null) linkCard(account),
          _SettingsCard(
            key: const Key('settings-theme'),
            icon: dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            title: SettingsText.themeTitle,
            note: SettingsText.themeNote,
            action: Switch(
              key: const Key('settings-theme-switch'),
              value: dark,
              onChanged: (value) =>
                  ref.read(themeModeProvider.notifier).setDark(value),
            ),
            onTap: () => ref.read(themeModeProvider.notifier).setDark(!dark),
          ),
          if (employees != null || audit != null || ledger)
            const _GroupLabel('الإدارة'),
          if (employees != null) linkCard(employees),
          if (audit != null) linkCard(audit),
          if (ledger) const _LedgerTile(onOpen: _openLedger),
          const _GroupLabel('التطبيق'),
          if (development != null) linkCard(development),
          _SettingsCard(
            key: const Key('settings-about'),
            icon: Icons.info_outline_rounded,
            title: SettingsText.aboutTitle,
            note:
                '${SettingsText.environment}: ${kBuildEnvironment.label ?? SettingsText.production}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.noLanguage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({this.name, this.role});

  final String? name;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    return Container(
      key: const Key('settings-header'),
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: gold.withValues(alpha: 0.55)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _pill(
            context,
            Text(
              AppStrings.settings,
              style: cairo(20, 900, color: Colors.white),
            ),
          ),
          if (name != null)
            _pill(
              context,
              Column(
                key: const Key('settings-owner'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    role ?? SettingsText.ownerRole,
                    style: cairo(11, 700, color: const Color(0xFFFDE68A)),
                  ),
                  Text(name!, style: cairo(13, 800, color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, Widget child) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: sectionGold(context).withValues(alpha: 0.45)),
      ),
    child: child,
  );
}

/// One settings card: gold icon circle (start), title and description,
/// the action at the end. Same minimum height for every card.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.note,
    this.action,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String note;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: gold.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: gold.withValues(alpha: 0.16),
                        ),
                        child: Icon(icon, size: 20, color: gold),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: cairo(15, 800, color: scheme.onSurface),
                            ),
                            Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: cairo(
                                12,
                                600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        IconTheme.merge(
                          data: IconThemeData(color: gold),
                          child: action!,
                        ),
                      ],
                    ],
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: cairo(13, 800, color: sectionGold(context)),
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.onOpen});

  final void Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      key: const Key('financial-ledger'),
      icon: Icons.menu_book_outlined,
      title: AppStrings.financialLedger,
      note: 'يفتح صفحة القيود. الإجماليات لا تظهر هنا.',
      action: TextButton(
        key: const Key('ledger-open'),
        onPressed: () => onOpen(context),
        child: const Text('فتح'),
      ),
      onTap: () => onOpen(context),
    );
  }
}
