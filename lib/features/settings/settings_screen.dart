import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/strings.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/section_kit.dart';
import '../../ui/widgets/export_pdf_button.dart';
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
  static const employeesNote = 'تحصيل كل موظف: المحصّل، المعلّق، والنقد لديه.';
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
          path: '/settings/employee-totals',
          icon: Icons.groups_outlined,
        ),
      const _SettingsLink(
        tileKey: Key('settings-link-account'),
        title: SettingsText.accountTitle,
        note: SettingsText.accountNote,
        path: '/account',
        icon: Icons.manage_accounts_outlined,
      ),
    ];
    return SectionTheme(
      child: ListView(
        key: screenKey,
        padding: pagePadding(width),
        children: [
          _HeaderBand(
            name: summary?.displayName,
            role: summary == null ? null : roleLabel(summary.role),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final link in links)
            _SettingsCard(
              key: link.tileKey,
              icon: link.icon,
              title: link.title,
              note: link.note,
              action: forwardChevron(context),
              onTap: () => context.go(link.path),
            ),
          // Device-local: the theme, same switch as حسابي (no server call).
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
          if (ledger) const _LedgerTile(),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E7A55), Color(0xFF064E36)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: gold.withValues(alpha: 0.8), width: 1.2),
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
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: sectionGold(context).withValues(alpha: 0.7)),
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
    this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String note;
  final Widget? action;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Material(
        color: const Color(0xFF0B0B0F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: gold.withValues(alpha: 0.8), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A2A2E), Color(0xFF0B0B0F)],
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 92 * scale),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF5C02E),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(icon, color: sectionButtonInk),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: cairo(15, 800, color: Colors.white),
                              ),
                              Text(
                                note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: cairo(11.5, 600, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          IconTheme.merge(
                            data: const IconThemeData(color: Color(0xFFF5C02E)),
                            child: action!,
                          ),
                        ],
                      ],
                    ),
                    ?child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page total as an Arabic currency label. The server key (`LYD`, `EGP`) is
/// not shown beside the symbol.
String _ledgerTotal(MoneyFormatter money, String code, MoneyValue units) {
  final currency = Currency.fromCode(code);
  if (units.isInvalid || units.units == null) return MoneyValue.invalidLabel;
  if (currency == null) return money.formatNumber(units.units!);
  return money.formatOrDash(units, currency);
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canViewFinancialLedger) {
      return const SizedBox.shrink();
    }
    final page = ref.watch(financialLedgerProvider);
    final money = ref.watch(apiLayerProvider).money;
    final online = ref.watch(onlineProvider);
    final ink = cairo(12.5, 700, color: Colors.white);
    return _SettingsCard(
      key: const Key('financial-ledger'),
      icon: Icons.menu_book_outlined,
      title: AppStrings.financialLedger,
      note: SettingsText.ledgerNote,
      child: DefaultTextStyle.merge(
        style: ink,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExportPdfButton(),
              page.when(
                loading: () => const SkeletonBox(height: 48),
                error: (error, _) => presentFailure(
                  ref.read(errorHandlerProvider).toFailure(error),
                  onRetry: online
                      ? () => ref.invalidate(financialLedgerProvider)
                      : null,
                  retryKey: const Key('settings-retry'),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.pageTotals, style: ink),
                    for (final entry in data.pageTotals.entries)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.xs,
                        ),
                        child: MoneyText(
                          _ledgerTotal(money, entry.key, entry.value),
                          key: Key('ledger-total-${entry.key}'),
                          style: cairo(14, 800, color: const Color(0xFFF5C02E)),
                        ),
                      ),
                    if (data.page.items.isEmpty)
                      const EmptyPane(message: AppStrings.emptyLedger),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
