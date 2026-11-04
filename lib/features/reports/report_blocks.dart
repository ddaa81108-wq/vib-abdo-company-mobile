// التقارير الذكية blocks (Ali, 2026-11-04), arranged like the website.
// Every figure is a server field shown as-is: nothing is added, subtracted
// or converted on the device.
import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/widgets/labeled_money.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';

class RText {
  static const heroTitle = 'صافي المركز — لنا';
  static const heroNote = 'صافي مركز مالي، وليس ربحًا أو نقدًا متاحًا للصرف.';
  static const ours = 'صافي حسابات لنا';
  static const oursNote = 'العملاء + الشركات بعد خصم أرصدتهم الدائنة.';
  static const theirs = 'صافي حسابات علينا';
  static const theirsNote = 'باقي المشتريات + الأمانات الليبية.';
  static const sources = 'من أين جاءت الأرقام؟';
  static const sourcesHint = 'اضغط المصدر لرؤية الحسابات التي تكوّن إجماليه.';
  static const customers = 'حسابات العملاء';
  static const companies = 'حسابات الشركات';
  static const libyan = 'الأمانات الليبية';
  static const egyptian = 'الأمانات المصرية';
  static const cash = 'النقد المسجل بالخزينة';
  static const accounts = 'حساب / دفتر';
  static const details = 'عرض التفاصيل';
  static const egpSeparate = 'المصري منفصل:';
  static const egpRate = 'السعر المسجل:';
  static const egpConverted = 'المقابل المحتسب:';
  static const today = 'ماذا حدث اليوم؟';
  static const todayNote =
      'حركة اليوم حسب توقيت المنظومة؛ منفصلة عن الأرصدة الحالية.';
  static const added = 'ديون وأرصدة افتتاحية أضيفت اليوم';
  static const payments = 'تسديدات العملاء والشركات';
  static const liabilities = 'أثر الديون علينا اليوم';
  static const cashIn = 'نقد دخل الخزينة';
  static const cashOut = 'نقد خرج من الخزينة';
  static const todayFoot =
      'خروج النقد ليس بالضرورة مصروفًا. هذه قيم المعاملات السارية بعد التصحيح والإلغاء.';
  static const follow = 'يحتاج متابعة';
  static const followNote = 'بنود فعلية مسجلة، دون تنبؤات أو أحكام آلية.';
  static const followEmpty = 'لا توجد بنود معلقة مسجلة';
  static const fiveAm = 'مقارنة الخامسة صباحًا';
  static const fiveAmTag = 'بتوقيت ليبيا · د.ل';
  static const fiveAmSaved = 'لقطة محفوظة وثابتة';
  static const fiveAmNote = 'آخر اللقطات المسجلة أمامك، دون إنشاء أيام مفقودة.';
  static const day = 'يوم العمل';
  static const net5 = 'صافي 05:00';
  static const open = 'فتح';
}

const _gloss = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2A2A2E), Color(0xFF0B0B0F)],
);

/// The big dark صافي المركز card.
class ReportHero extends StatelessWidget {
  const ReportHero({required this.row, required this.money, super.key});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final gold = sectionGold(context);
    return Container(
      key: const Key('report-current'),
      decoration: BoxDecoration(
        gradient: _gloss,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: gold.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: gold, width: 4)),
        ),
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    RText.heroTitle,
                    style: cairo(15, 800, color: Colors.white),
                  ),
                ),
                LtrText(
                  row.date ?? AppStrings.dash,
                  style: cairo(12, 700, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ScaledMoney(
                money.formatOrDash(row.netUnits, Currency.lyd),
                key: const Key('report-hero-net'),
                style: context.textExtras.amountLarge.copyWith(
                  color: const Color(0xFFF5C02E),
                  fontSize: 34,
                ),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(RText.heroNote, style: cairo(12, 600, color: Colors.white70)),
            const SizedBox(height: AppSpacing.sm),
            ReportStatusChip(status: row.status),
          ],
        ),
      ),
    );
  }
}

/// Equal-size figure card: title (with optional icon), big amount, subtitle.
class FigureCard extends StatelessWidget {
  const FigureCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.highlight = false,
    this.height = 118,
    super.key,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlight;
  final double height;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gold = sectionGold(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    Widget line(Widget child) => SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: child,
      ),
    );
    return Material(
      color: look.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(
          color: highlight ? gold : look.cardBorder,
          width: highlight ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height * scale,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: gold, width: 3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: gold),
                      const SizedBox(width: 6),
                    ],
                    Text(title, style: cairo(13.5, 800, color: look.ink)),
                  ],
                ),
              ),
              line(
                MoneyText(
                  value,
                  style: context.textExtras.amountLarge.copyWith(
                    color: look.ink,
                    fontSize: 22,
                  ),
                ),
              ),
              if (subtitle != null)
                line(
                  Text(
                    subtitle!,
                    maxLines: 1,
                    style: cairo(11, 600, color: look.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cards in rows of [columns] (2 on phones), all the same width.
class EqualGrid extends StatelessWidget {
  const EqualGrid({required this.children, this.wide = 4, super.key});

  final List<Widget> children;
  final int wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final min = 150.0 * (scale < 1.2 ? 1.0 : scale);
        const gap = AppSpacing.sm;
        var columns = width >= 900 ? wide : 2;
        while (columns > 1 && (width - gap * (columns - 1)) / columns < min) {
          columns--;
        }
        final tile = ((width - gap * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: tile, child: child),
          ],
        );
      },
    );
  }
}

/// صافي حسابات لنا / علينا, from the report row.
class ReportBalances extends StatelessWidget {
  const ReportBalances({required this.row, required this.money, super.key});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return EqualGrid(
      key: const Key('report-balances'),
      wide: 2,
      children: [
        FigureCard(
          key: const Key('report-ours'),
          title: RText.ours,
          icon: Icons.south_west_rounded,
          value: money.formatOrDash(row.receivablesUnits, Currency.lyd),
          subtitle: RText.oursNote,
        ),
        FigureCard(
          key: const Key('report-theirs'),
          title: RText.theirs,
          icon: Icons.north_east_rounded,
          value: money.formatOrDash(row.liabilitiesUnits, Currency.lyd),
          subtitle: RText.theirsNote,
        ),
      ],
    );
  }
}

/// من أين جاءت الأرقام؟ — each section's own server summary (list total
/// and card count); tapping opens that section. Sections the user cannot
/// read are left out.
class ReportSources extends ConsumerWidget {
  const ReportSources({required this.row, required this.money, super.key});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  static const _sections = [
    (AccountSection.customers, RText.customers),
    (AccountSection.companies, RText.companies),
    (AccountSection.libyanDeposits, RText.libyan),
    (AccountSection.egyptianDeposits, RText.egyptian),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    final cards = <Widget>[];
    for (final (section, title) in _sections) {
      if (!permissions.canRead(section.sectionKey)) continue;
      final summary = ref
          .watch(accountsProvider(section))
          .asData
          ?.value
          .summary;
      final count = summary?.activeCards;
      cards.add(
        FigureCard(
          key: Key('report-source-${section.path}'),
          title: title,
          value: money.formatOrDash(summary?.netBalanceUnits, section.currency),
          subtitle:
              '${count == null ? AppStrings.dash : '$count'} ${RText.accounts} · ${RText.details}',
          highlight: section == AccountSection.libyanDeposits,
          onTap: () => context.go('/${section.path}'),
        ),
      );
    }
    if (permissions.canRead(SectionKey.treasury)) {
      final cash = ref.watch(treasuryProvider).asData?.value;
      cards.add(
        FigureCard(
          key: const Key('report-source-treasury'),
          title: RText.cash,
          value: money.formatOrDash(cash?.activeCashUnits, Currency.lyd),
          subtitle: '1 ${RText.accounts} · ${RText.details}',
          onTap: () => context.go('/treasury'),
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    final look = context.look;
    return SectionCard(
      key: const Key('report-sources'),
      title: RText.sources,
      note: RText.sourcesHint,
      trailing: LtrText(
        row.date ?? AppStrings.dash,
        style: cairo(12, 700, color: look.muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EqualGrid(wide: 3, children: cards),
          const SizedBox(height: AppSpacing.sm),
          Container(
            key: const Key('report-egp-note'),
            padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: look.strip,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: 4,
              children: [
                _pair(
                  context,
                  RText.egpSeparate,
                  money.formatOrDash(row.egyptianUnits, Currency.egp),
                ),
                _pair(
                  context,
                  RText.egpRate,
                  money.formatDecimalOrDash(row.egyptianRate),
                ),
                _pair(
                  context,
                  RText.egpConverted,
                  money.formatOrDash(row.egyptianConvertedUnits, Currency.lyd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pair(BuildContext context, String label, String value) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: cairo(11.5, 700, color: context.look.muted),
        ),
        TextSpan(
          text: '\u2066$value\u2069',
          style: cairo(12, 800, color: context.look.ink),
        ),
      ],
    ),
  );
}

/// ماذا حدث اليوم؟ — the row's `daily` figures. Hidden when absent.
class ReportToday extends StatelessWidget {
  const ReportToday({required this.row, required this.money, super.key});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final daily = row.daily;
    if (daily == null) return const SizedBox.shrink();
    String lyd(MoneyValue? v) => money.formatOrDash(v, Currency.lyd);
    return SectionCard(
      key: const Key('report-today'),
      title: RText.today,
      note: RText.todayNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EqualGrid(
            wide: 3,
            children: [
              FigureCard(
                height: 92,
                title: RText.added,
                value: lyd(daily.receivablesAddedUnits),
              ),
              FigureCard(
                height: 92,
                title: RText.payments,
                value: lyd(daily.paymentsUnits),
              ),
              FigureCard(
                height: 92,
                title: RText.liabilities,
                value: lyd(daily.liabilitiesEffectUnits),
              ),
              FigureCard(
                key: const Key('report-today-cash-in'),
                height: 92,
                title: RText.cashIn,
                value: lyd(daily.cashInUnits),
              ),
              FigureCard(
                key: const Key('report-today-cash-out'),
                height: 92,
                title: RText.cashOut,
                value: lyd(daily.cashOutUnits),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            RText.todayFoot,
            style: cairo(11, 600, color: context.look.muted),
          ),
        ],
      ),
    );
  }
}

/// يحتاج متابعة — the row's own reasons (server); a ✓ when there are none.
class ReportFollowUp extends StatelessWidget {
  const ReportFollowUp({required this.row, required this.money, super.key});

  final DailyReportRowDto row;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final colors = context.statusColors;
    return SectionCard(
      key: const Key('report-follow'),
      title: RText.follow,
      note: RText.followNote,
      child: row.reasons.isEmpty
          ? Column(
              key: const Key('report-follow-empty'),
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: colors.cashPositiveText,
                  size: 30,
                ),
                const SizedBox(height: 4),
                Text(RText.followEmpty, style: cairo(13, 800, color: look.ink)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final reason in row.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: sectionGold(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason.text ?? reason.label ?? AppStrings.dash,
                            style: cairo(12.5, 700, color: look.ink),
                          ),
                        ),
                        MoneyText(
                          money.formatOrDash(reason.changeUnits, Currency.lyd),
                          style: cairo(12.5, 800, color: look.ink),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// مقارنة الخامسة صباحًا — the rows' recorded 05:00 snapshots. الفرق shows
/// only the server's `netChangeUnits`; nothing is subtracted here.
class ReportFiveAm extends StatelessWidget {
  const ReportFiveAm({
    required this.rows,
    required this.money,
    required this.onOpen,
    super.key,
  });

  final List<DailyReportRowDto> rows;
  final MoneyFormatter money;
  final ValueChanged<DailyReportRowDto> onOpen;

  @override
  Widget build(BuildContext context) {
    final snaps = [
      for (final row in rows)
        if (row.fiveAmClosing?.netUnits != null) row,
    ].take(20).toList();
    if (snaps.isEmpty) return const SizedBox.shrink();
    final look = context.look;
    final colors = context.statusColors;
    final latest = snaps.first;
    final showChange = snaps.any((r) => r.netChangeUnits != null);
    Widget head(String t) => Text(
      t,
      textAlign: TextAlign.center,
      style: cairo(12, 800, color: sectionStripInk),
    );
    return SectionCard(
      key: const Key('report-five-am'),
      title: RText.fiveAm,
      trailing: Text(RText.fiveAmTag, style: cairo(11, 700, color: look.muted)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('report-five-am-latest'),
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: look.strip,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: look.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LtrText(
                        latest.date ?? AppStrings.dash,
                        style: cairo(12, 700, color: look.muted),
                      ),
                      Text(
                        RText.fiveAmSaved,
                        style: cairo(11, 600, color: look.muted),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MoneyText(
                      money.formatOrDash(
                        latest.fiveAmClosing!.netUnits,
                        Currency.lyd,
                      ),
                      style: context.textExtras.amountLarge.copyWith(
                        color: look.ink,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(RText.fiveAmNote, style: cairo(11, 600, color: look.muted)),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: sectionStripGradient,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: head(RText.day)),
                      Expanded(flex: 4, child: head(RText.net5)),
                      if (showChange)
                        Expanded(flex: 4, child: head(AppStrings.netChange)),
                      Expanded(flex: 2, child: head(RText.open)),
                    ],
                  ),
                ),
                for (final row in snaps)
                  Container(
                    key: Key('report-five-am-${row.sequence}'),
                    decoration: BoxDecoration(
                      color: row == latest
                          ? sectionGold(context).withValues(alpha: 0.10)
                          : null,
                      border: Border(
                        bottom: BorderSide(color: look.cardBorder),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: LtrText(
                              row.date ?? AppStrings.dash,
                              style: cairo(12.5, 700, color: look.ink),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: MoneyText(
                                money.formatOrDash(
                                  row.fiveAmClosing!.netUnits,
                                  Currency.lyd,
                                ),
                                style: cairo(12.5, 700, color: look.ink),
                              ),
                            ),
                          ),
                        ),
                        if (showChange)
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: MoneyText(
                                  money.formatOrDash(
                                    row.netChangeUnits,
                                    Currency.lyd,
                                  ),
                                  style: cairo(
                                    12.5,
                                    800,
                                    color: (row.netChangeUnits?.units ?? 0) < 0
                                        ? colors.cashNegative
                                        : colors.cashPositiveText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: IconButton(
                              key: Key('report-open-${row.sequence}'),
                              tooltip: RText.open,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: sectionGold(context),
                              ),
                              onPressed: () => onOpen(row),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
