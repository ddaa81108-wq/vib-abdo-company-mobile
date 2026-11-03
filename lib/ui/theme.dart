import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app face (IBM Plex Sans Arabic, OFL). Its digits are tabular, so
/// amounts and Arabic text share it.
const kAppFont = 'IBMPlexSansArabic';

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final colors = dark ? AppColors.dark : AppColors.light;
  final status = dark ? AppStatusColors.dark : AppStatusColors.light;
  final sidebar = dark
      ? AppSidebarPalette.glassNavy
      : AppSidebarPalette.fintechLight;
  final look = dark ? AppLook.dark : AppLook.light;
  final extras = AppTextExtras.standard;
  final base = cairo(13, 500, color: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    fontFamily: kAppFont,
    shadowColor: scheme.shadow,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      headlineMedium: cairo(20, 800, color: scheme.onSurface),
      headlineSmall: cairo(19, 800, color: scheme.onSurface),
      titleLarge: cairo(18, 800, color: scheme.onSurface),
      titleMedium: cairo(16, 800, color: scheme.onSurface),
      titleSmall: cairo(14, 700, color: scheme.onSurface),
      bodyLarge: cairo(14, 500, color: scheme.onSurface),
      bodyMedium: base,
      bodySmall: cairo(11, 500, color: scheme.onSurfaceVariant),
      labelLarge: cairo(13, 700, color: scheme.onSurface),
      labelMedium: cairo(12, 600, color: scheme.onSurface),
      labelSmall: cairo(11, 800, color: scheme.onSurface),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.sidebarBg,
      foregroundColor: sidebar.bright,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: cairo(16, 800, color: sidebar.bright),
      iconTheme: IconThemeData(color: sidebar.bright),
    ),
    cardTheme: CardThemeData(
      color: look.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: dark ? const Color(0x00000000) : scheme.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: look.cardBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.fieldBg,
      isDense: true,
      labelStyle: cairo(13, 600, color: colors.label),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: look.button,
        foregroundColor: look.onButton,
        textStyle: cairo(16, 700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: look.accent,
        side: BorderSide(color: look.cardBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: look.bar,
      indicatorColor: look.barIndicator,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        cairo(11, 700, color: sidebar.shine),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: sidebar.light)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.sidebarBg,
      indicatorColor: sidebar.glow,
      selectedIconTheme: IconThemeData(color: sidebar.bright),
      unselectedIconTheme: IconThemeData(color: colors.sidebarMuted),
      selectedLabelTextStyle: cairo(12, 800, color: sidebar.bright),
      unselectedLabelTextStyle: cairo(12, 600, color: colors.sidebarMuted),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: cairo(13, 600, color: scheme.onInverseSurface),
    ),
    extensions: [colors, status, sidebar, extras, look],
  );
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF2563EB),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE8EFFE),
  onPrimaryContainer: Color(0xFF1E3A8A),
  secondary: Color(0xFF7C3AED),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF1EAFE),
  onSecondaryContainer: Color(0xFF4C1D95),
  tertiary: Color(0xFF166534),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFDC2626),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF991B1B),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF0F172A),
  onSurfaceVariant: Color(0xFF5B6B80),
  outline: Color(0xFFE4E8F1),
  outlineVariant: Color(0xFFEEF1F6),
  shadow: Color(0x140F172A),
  scrim: Color(0x990F172A),
  inverseSurface: Color(0xFF0F172A),
  onInverseSurface: Color(0xFFF5F7FB),
  inversePrimary: Color(0xFF93C5FD),
  surfaceTint: Color(0xFF2563EB),
  surfaceContainerLowest: Color(0xFFF5F7FB),
  surfaceContainerLow: Color(0xFFF8FAFC),
  surfaceContainer: Color(0xFFF1F4F9),
  surfaceContainerHigh: Color(0xFFEDF1F7),
  surfaceContainerHighest: Color(0xFFE4E8F1),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF60A5FA),
  onPrimary: Color(0xFF0B1020),
  primaryContainer: Color(0xFF1A2550),
  onPrimaryContainer: Color(0xFFDBEAFE),
  secondary: Color(0xFFA855F7),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFF2A1B4A),
  onSecondaryContainer: Color(0xFFF3E8FF),
  tertiary: Color(0xFF22C55E),
  onTertiary: Color(0xFF06140C),
  error: Color(0xFFF87171),
  onError: Color(0xFF2A0B0B),
  errorContainer: Color(0xFF3A1A22),
  onErrorContainer: Color(0xFFFECACA),
  surface: Color(0xFF131A2C),
  onSurface: Color(0xFFE5E7EB),
  onSurfaceVariant: Color(0xFF94A3B8),
  outline: Color(0xFF263252),
  outlineVariant: Color(0xFF1C2540),
  shadow: Color(0x66000000),
  scrim: Color(0xCC05070F),
  inverseSurface: Color(0xFFE5E7EB),
  onInverseSurface: Color(0xFF0B1020),
  inversePrimary: Color(0xFF2563EB),
  surfaceTint: Color(0xFF60A5FA),
  surfaceContainerLowest: Color(0xFF0B1020),
  surfaceContainerLow: Color(0xFF111827),
  surfaceContainer: Color(0xFF151C30),
  surfaceContainerHigh: Color(0xFF1A2238),
  surfaceContainerHighest: Color(0xFF212A42),
);

TextStyle cairo(
  double size,
  double weight, {
  Color? color,
  double height = 1.35,
}) {
  return TextStyle(
    fontFamily: kAppFont,
    fontSize: size,
    height: height,
    color: color,
    fontWeight: _weight(weight),
  );
}

TextStyle mono(double size, FontWeight weight, {Color? color}) {
  return TextStyle(
    fontFamily: kAppFont,
    fontSize: size,
    height: 1.3,
    color: color,
    fontWeight: weight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

FontWeight _weight(double weight) {
  if (weight >= 700) return FontWeight.w700;
  if (weight >= 600) return FontWeight.w600;
  if (weight >= 500) return FontWeight.w500;
  return FontWeight.w400;
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.label,
    required this.sidebarBg,
    required this.sidebarMuted,
    required this.noteBg,
    required this.noteLine,
    required this.noteText,
    required this.success,
    required this.successBg,
    required this.successLine,
    required this.overlay,
    required this.fieldBg,
  });

  final Color label;
  final Color sidebarBg;
  final Color sidebarMuted;
  final Color noteBg;
  final Color noteLine;
  final Color noteText;
  final Color success;
  final Color successBg;
  final Color successLine;
  final Color overlay;
  final Color fieldBg;

  static const light = AppColors(
    label: Color(0xFF334155),
    sidebarBg: Color(0xFFF5F7FB),
    sidebarMuted: Color(0xFF5B6B80),
    noteBg: Color(0xFFEFF4FF),
    noteLine: Color(0xFFD6E2FB),
    noteText: Color(0xFF1E3A8A),
    success: Color(0xFF166534),
    successBg: Color(0xFFE8F5EC),
    successLine: Color(0xFFBBE5C8),
    overlay: Color(0x990F172A),
    fieldBg: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    label: Color(0xFFCBD5E1),
    sidebarBg: Color(0xFF0B1020),
    sidebarMuted: Color(0xFF94A3B8),
    noteBg: Color(0xFF141E3A),
    noteLine: Color(0xFF263A6B),
    noteText: Color(0xFFBFDBFE),
    success: Color(0xFF4ADE80),
    successBg: Color(0xFF10291C),
    successLine: Color(0xFF1F5134),
    overlay: Color(0xCC05070F),
    fieldBg: Color(0xFF0F1526),
  );

  @override
  AppColors copyWith({
    Color? label,
    Color? sidebarBg,
    Color? sidebarMuted,
    Color? noteBg,
    Color? noteLine,
    Color? noteText,
    Color? success,
    Color? successBg,
    Color? successLine,
    Color? overlay,
    Color? fieldBg,
  }) {
    return AppColors(
      label: label ?? this.label,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      noteBg: noteBg ?? this.noteBg,
      noteLine: noteLine ?? this.noteLine,
      noteText: noteText ?? this.noteText,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      successLine: successLine ?? this.successLine,
      overlay: overlay ?? this.overlay,
      fieldBg: fieldBg ?? this.fieldBg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors && t >= 0.5 ? other : this;
}

@immutable
class AppSidebarPalette extends ThemeExtension<AppSidebarPalette> {
  const AppSidebarPalette({
    required this.tint,
    required this.edge,
    required this.line,
    required this.light,
    required this.shine,
    required this.bright,
    required this.base,
    required this.ink,
    required this.glow,
    required this.glowSoft,
  });

  final Color tint;
  final Color edge;
  final Color line;
  final Color light;
  final Color shine;
  final Color bright;
  final Color base;
  final Color ink;
  final Color glow;
  final Color glowSoft;

  /// Concept 1 «زجاج كحلي نيون»: light ink and neon blue on deep navy.
  static const glassNavy = AppSidebarPalette(
    tint: Color(0xFF111827),
    edge: Color(0xFF3B82F6),
    line: Color(0xFF263252),
    light: Color(0xFF93C5FD),
    shine: Color(0xFFE2E8F0),
    bright: Color(0xFFF1F5F9),
    base: Color(0xFF60A5FA),
    ink: Color(0xFF0B1020),
    glow: Color(0x333B82F6),
    glowSoft: Color(0x143B82F6),
  );

  /// Concept 3 «فنتك بسيط»: dark ink and one blue on a pale canvas.
  static const fintechLight = AppSidebarPalette(
    tint: Color(0xFFEFF4FF),
    edge: Color(0xFF2563EB),
    line: Color(0xFFE4E8F1),
    light: Color(0xFF2563EB),
    shine: Color(0xFF1E293B),
    bright: Color(0xFF0F172A),
    base: Color(0xFF2563EB),
    ink: Color(0xFFFFFFFF),
    glow: Color(0x242563EB),
    glowSoft: Color(0x0F2563EB),
  );

  @override
  AppSidebarPalette copyWith({
    Color? tint,
    Color? edge,
    Color? line,
    Color? light,
    Color? shine,
    Color? bright,
    Color? base,
    Color? ink,
    Color? glow,
    Color? glowSoft,
  }) {
    return AppSidebarPalette(
      tint: tint ?? this.tint,
      edge: edge ?? this.edge,
      line: line ?? this.line,
      light: light ?? this.light,
      shine: shine ?? this.shine,
      bright: bright ?? this.bright,
      base: base ?? this.base,
      ink: ink ?? this.ink,
      glow: glow ?? this.glow,
      glowSoft: glowSoft ?? this.glowSoft,
    );
  }

  @override
  AppSidebarPalette lerp(ThemeExtension<AppSidebarPalette>? other, double t) =>
      other is AppSidebarPalette && t >= 0.5 ? other : this;
}

/// CSS `linear-gradient(145deg)` in physical space, so RTL does not mirror it.
const _statusGradientBegin = Alignment(-0.5736, -0.8192);
const _statusGradientEnd = Alignment(0.5736, 0.8192);

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.onStatus,
    required this.newDebt,
    required this.warningDebt,
    required this.overdueDebt,
    required this.zeroBalance,
    required this.creditBalance,
    required this.flatNew,
    required this.flatWarning,
    required this.flatOverdue,
    required this.flatZero,
    required this.flatCredit,
    required this.accentNew,
    required this.accentWarning,
    required this.accentOverdue,
    required this.accentZero,
    required this.accentCredit,
    required this.debtText,
    required this.creditText,
    required this.badgeBg,
    required this.cashPositive,
    required this.cashPositiveText,
    required this.cashNegative,
    required this.chipNormalBg,
    required this.chipNormalFg,
    required this.chipReviewBg,
    required this.chipReviewFg,
    required this.chipCriticalBg,
    required this.chipCriticalFg,
    required this.unlinkedPending,
    required this.unlinkedApproved,
    required this.dayTones,
    required this.neutralCard,
    required this.zeroCardBorder,
  });

  final Color onStatus;
  final LinearGradient newDebt;
  final LinearGradient warningDebt;
  final LinearGradient overdueDebt;
  final LinearGradient zeroBalance;
  final LinearGradient creditBalance;
  final Color flatNew;
  final Color flatWarning;
  final Color flatOverdue;
  final Color flatZero;
  final Color flatCredit;
  final Color accentNew;
  final Color accentWarning;
  final Color accentOverdue;
  final Color accentZero;
  final Color accentCredit;
  final Color debtText;
  final Color creditText;
  final Color badgeBg;

  /// Fill for a positive cash tile. Dark enough that white labels stay AA.
  final Color cashPositive;

  /// Positive amount ink. Same hue as [cashPositive], lighter on dark surfaces.
  final Color cashPositiveText;
  final Color cashNegative;
  final Color chipNormalBg;
  final Color chipNormalFg;
  final Color chipReviewBg;
  final Color chipReviewFg;
  final Color chipCriticalBg;
  final Color chipCriticalFg;
  final Color unlinkedPending;
  final Color unlinkedApproved;
  final List<Color> dayTones;
  final Color neutralCard;

  /// `.customer-card.zero-balance` border from the web CSS.
  final Color zeroCardBorder;

  static const light = AppStatusColors(
    onStatus: Color(0xFFFFFFFF),
    newDebt: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF3548FF), Color(0xFF211CAF), Color(0xFF15126F)],
      stops: [0, 0.52, 1],
    ),
    warningDebt: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFFFF9A00), Color(0xFFE36D00), Color(0xFF9F3F00)],
      stops: [0, 0.52, 1],
    ),
    overdueDebt: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFFFF164E), Color(0xFFD30036), Color(0xFF870021)],
      stops: [0, 0.52, 1],
    ),
    zeroBalance: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF151515), Color(0xFF050505), Color(0xFF000000)],
      stops: [0, 0.58, 1],
    ),
    creditBalance: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF00C77B), Color(0xFF00965E), Color(0xFF00603E)],
      stops: [0, 0.52, 1],
    ),
    flatNew: Color(0xFF1769AA),
    flatWarning: Color(0xFFC08A08),
    flatOverdue: Color(0xFFB52835),
    flatZero: Color(0xFF5B3A29),
    flatCredit: Color(0xFF178447),
    accentNew: Color(0xFFE4E7FF),
    accentWarning: Color(0xFFFFF0CE),
    accentOverdue: Color(0xFFFFE2E9),
    accentZero: Color(0xFFE5E5E5),
    accentCredit: Color(0xFFDDFFF1),
    debtText: Color(0xFFDC2626),
    creditText: Color(0xFF166534),
    badgeBg: Color(0xFFDC2626),
    cashPositive: Color(0xFF087A50),
    cashPositiveText: Color(0xFF087A50),
    cashNegative: Color(0xFFB43131),
    chipNormalBg: Color(0xFFE7F7F1),
    chipNormalFg: Color(0xFF08795C),
    chipReviewBg: Color(0xFFFFF0C4),
    chipReviewFg: Color(0xFF91600D),
    chipCriticalBg: Color(0xFFFDE1E5),
    chipCriticalFg: Color(0xFFB32635),
    unlinkedPending: Color(0xFF4F5F73),
    unlinkedApproved: Color(0xFF178447),
    dayTones: [
      Color(0xFFEFF4FF),
      Color(0xFFF5F0FF),
      Color(0xFFECF8F0),
      Color(0xFFFDF1F1),
      Color(0xFFF7EEE3),
    ],
    neutralCard: Color(0xFFFFFFFF),
    zeroCardBorder: Color(0xFF737373),
  );

  static const dark = AppStatusColors(
    onStatus: Color(0xFFFFFFFF),
    newDebt: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF294B80), Color(0xFF1A3053)],
    ),
    warningDebt: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF78551E), Color(0xFF503912)],
    ),
    overdueDebt: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF813849), Color(0xFF552537)],
    ),
    zeroBalance: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF24262B), Color(0xFF14161A)],
    ),
    creditBalance: LinearGradient(
      begin: _statusGradientBegin,
      end: _statusGradientEnd,
      colors: [Color(0xFF24634F), Color(0xFF193E36)],
    ),
    flatNew: Color(0xFF294B80),
    flatWarning: Color(0xFF78551E),
    flatOverdue: Color(0xFF813849),
    flatZero: Color(0xFF24262B),
    flatCredit: Color(0xFF24634F),
    accentNew: Color(0xFFE4E7FF),
    accentWarning: Color(0xFFFFF0CE),
    accentOverdue: Color(0xFFFFE2E9),
    accentZero: Color(0xFFE5E5E5),
    accentCredit: Color(0xFFDDFFF1),
    debtText: Color(0xFFF87171),
    creditText: Color(0xFF4ADE80),
    badgeBg: Color(0xFFDC2626),
    cashPositive: Color(0xFF087A50),
    cashPositiveText: Color(0xFF0CB677),
    cashNegative: Color(0xFFB43131),
    chipNormalBg: Color(0xFFE7F7F1),
    chipNormalFg: Color(0xFF08795C),
    chipReviewBg: Color(0xFFFFF0C4),
    chipReviewFg: Color(0xFF91600D),
    chipCriticalBg: Color(0xFFFDE1E5),
    chipCriticalFg: Color(0xFFB32635),
    unlinkedPending: Color(0xFF4F5F73),
    unlinkedApproved: Color(0xFF178447),
    dayTones: [
      Color(0xFF16203A),
      Color(0xFF1E1935),
      Color(0xFF13261E),
      Color(0xFF2A1A1F),
      Color(0xFF231D18),
    ],
    neutralCard: Color(0xFF131A2C),
    zeroCardBorder: Color(0xFF737373),
  );

  @override
  AppStatusColors copyWith() => this;

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) =>
      other is AppStatusColors && t >= 0.5 ? other : this;
}

@immutable
class AppTextExtras extends ThemeExtension<AppTextExtras> {
  const AppTextExtras({
    required this.amountLarge,
    required this.amount,
    required this.tableNumber,
    required this.badge,
  });

  final TextStyle amountLarge;
  final TextStyle amount;
  final TextStyle tableNumber;
  final TextStyle badge;

  static final standard = AppTextExtras(
    amountLarge: mono(20, FontWeight.w800),
    amount: mono(14, FontWeight.w700),
    tableNumber: mono(11, FontWeight.w700),
    badge: mono(9, FontWeight.w800),
  );

  @override
  AppTextExtras copyWith({
    TextStyle? amountLarge,
    TextStyle? amount,
    TextStyle? tableNumber,
    TextStyle? badge,
  }) {
    return AppTextExtras(
      amountLarge: amountLarge ?? this.amountLarge,
      amount: amount ?? this.amount,
      tableNumber: tableNumber ?? this.tableNumber,
      badge: badge ?? this.badge,
    );
  }

  @override
  AppTextExtras lerp(ThemeExtension<AppTextExtras>? other, double t) =>
      other is AppTextExtras && t >= 0.5 ? other : this;
}

/// A glossy card finish (Ali, 2026-11-03): a vivid gradient of the card's
/// own tone, a soft diagonal white sheen on top, a crisp brighter border and
/// a soft glow of the same colour.
@immutable
class Gloss {
  const Gloss({
    required this.top,
    required this.bottom,
    required this.border,
    required this.glow,
    required this.ink,
    required this.amount,
    this.sheen = 0.14,
  });

  /// Gradient fill, top to bottom.
  final Color top;
  final Color bottom;

  /// 1px border, a step brighter than the fill.
  final Color border;

  /// Shadow colour under the card (already carries its alpha).
  final Color glow;

  /// Name and secondary text.
  final Color ink;

  /// Status word and amount.
  final Color amount;

  /// Opacity of the white sheen at the top corner.
  final double sheen;

  LinearGradient get fill => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  );

  /// Diagonal white highlight that fades out before the middle.
  LinearGradient get highlight => LinearGradient(
    begin: Alignment.topLeft,
    end: const Alignment(0.35, 0.55),
    colors: [
      Colors.white.withValues(alpha: sheen),
      Colors.white.withValues(alpha: 0),
    ],
  );

  List<BoxShadow> get glowShadow => [
    BoxShadow(color: glow, blurRadius: 18, offset: const Offset(0, 6)),
  ];

  BoxDecoration decoration(BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    gradient: fill,
    border: Border.all(color: border),
  );
}

/// Paints [Gloss.highlight] behind [child] (over the card fill, under the
/// text) without taking taps.
class GlossSheen extends StatelessWidget {
  const GlossSheen({
    required this.gloss,
    required this.radius,
    required this.child,
    super.key,
  });

  final Gloss gloss;
  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: gloss.highlight,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Visual tokens shared by the redesigned screens: concept 1
/// «زجاج كحلي نيون» (dark) and concept 3 «فنتك بسيط» (light), Ali 2026-11-03.
@immutable
class AppLook extends ThemeExtension<AppLook> {
  const AppLook({
    required this.page,
    required this.card,
    required this.cardBorder,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.violet,
    required this.success,
    required this.danger,
    required this.button,
    required this.onButton,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroFigure,
    required this.bar,
    required this.barIndicator,
    required this.barSelected,
    required this.barIdle,
    required this.strip,
    required this.glass,
    required this.glossDebt,
    required this.glossCredit,
    required this.glossZero,
    required this.glossHero,
    required this.glossBlue,
    required this.glossViolet,
    required this.glossGreen,
    required this.glossGrey,
  });

  /// Page canvas.
  final Color page;

  /// Card and tile surface.
  final Color card;

  /// Thin tinted card border.
  final Color cardBorder;

  /// Main text.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Accent text and icons (blue).
  final Color accent;

  /// Second accent (violet).
  final Color violet;

  /// Green accent and أمانة.
  final Color success;

  /// Red accent and دين.
  final Color danger;

  /// Primary button fill.
  final Color button;

  /// Primary button text.
  final Color onButton;

  /// Headline gradient start.
  final Color heroStart;

  /// Headline gradient end.
  final Color heroEnd;

  /// Text on the headline gradient.
  final Color onHero;

  /// Labels on the headline gradient.
  final Color onHeroMuted;

  /// Figures on the headline gradient.
  final Color heroFigure;

  /// Bottom bar fill.
  final Color bar;

  /// Selected-tab pill.
  final Color barIndicator;

  /// Selected tab icon and label.
  final Color barSelected;

  /// Idle tab icon and label.
  final Color barIdle;

  /// Top status strip fill.
  final Color strip;

  /// Dark mode uses tinted glass tiles; light mode uses flat white cards
  /// with a soft shadow.
  final bool glass;

  /// Glossy finishes: customer cards (دين, أمانة, zero), the summary card,
  /// and the home tile tints.
  final Gloss glossDebt;
  final Gloss glossCredit;
  final Gloss glossZero;
  final Gloss glossHero;
  final Gloss glossBlue;
  final Gloss glossViolet;
  final Gloss glossGreen;
  final Gloss glossGrey;

  static const light = AppLook(
    page: Color(0xFFF5F7FB),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE4E8F1),
    ink: Color(0xFF0F172A),
    muted: Color(0xFF5B6B80),
    accent: Color(0xFF2563EB),
    violet: Color(0xFF7C3AED),
    success: Color(0xFF166534),
    danger: Color(0xFFDC2626),
    button: Color(0xFF2563EB),
    onButton: Color(0xFFFFFFFF),
    heroStart: Color(0xFF1E3A8A),
    heroEnd: Color(0xFF2563EB),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFDBEAFE),
    heroFigure: Color(0xFFFFFFFF),
    bar: Color(0xFFFFFFFF),
    barIndicator: Color(0xFFE8EFFE),
    barSelected: Color(0xFF1D4ED8),
    barIdle: Color(0xFF5B6B80),
    strip: Color(0xFFFFFFFF),
    glass: false,
    glossDebt: Gloss(
      top: Color(0xFFFFF5F5),
      bottom: Color(0xFFFFE4E6),
      border: Color(0xFFFCA5A5),
      glow: Color(0x2EDC2626),
      ink: Color(0xFF0F172A),
      amount: Color(0xFFB91C1C),
      sheen: 0.7,
    ),
    glossCredit: Gloss(
      top: Color(0xFFF3FDF6),
      bottom: Color(0xFFDCFCE7),
      border: Color(0xFF86EFAC),
      glow: Color(0x2E16A34A),
      ink: Color(0xFF0F172A),
      amount: Color(0xFF166534),
      sheen: 0.7,
    ),
    glossZero: Gloss(
      top: Color(0xFF2A2D35),
      bottom: Color(0xFF0B0B0F),
      border: Color(0xFF4B5060),
      glow: Color(0x400B0B0F),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFE5E7EB),
      sheen: 0.16,
    ),
    glossHero: Gloss(
      top: Color(0xFF1D4ED8),
      bottom: Color(0xFF1E3A8A),
      border: Color(0xFF3B82F6),
      glow: Color(0x4D2563EB),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.12,
    ),
    glossBlue: Gloss(
      top: Color(0xFFFFFFFF),
      bottom: Color(0xFFEAF1FE),
      border: Color(0xFFBFD3FA),
      glow: Color(0x242563EB),
      ink: Color(0xFF0F172A),
      amount: Color(0xFF2563EB),
      sheen: 0.8,
    ),
    glossViolet: Gloss(
      top: Color(0xFFFFFFFF),
      bottom: Color(0xFFF1EAFE),
      border: Color(0xFFD8C6FB),
      glow: Color(0x247C3AED),
      ink: Color(0xFF0F172A),
      amount: Color(0xFF7C3AED),
      sheen: 0.8,
    ),
    glossGreen: Gloss(
      top: Color(0xFFFFFFFF),
      bottom: Color(0xFFE7F6EC),
      border: Color(0xFFA7E3BC),
      glow: Color(0x24166534),
      ink: Color(0xFF0F172A),
      amount: Color(0xFF166534),
      sheen: 0.8,
    ),
    glossGrey: Gloss(
      top: Color(0xFFFFFFFF),
      bottom: Color(0xFFEEF1F6),
      border: Color(0xFFD5DBE5),
      glow: Color(0x1F0F172A),
      ink: Color(0xFF0F172A),
      amount: Color(0xFF475569),
      sheen: 0.8,
    ),
  );

  static const dark = AppLook(
    page: Color(0xFF0B1020),
    card: Color(0xFF131A2C),
    cardBorder: Color(0xFF232C48),
    ink: Color(0xFFE5E7EB),
    muted: Color(0xFF94A3B8),
    accent: Color(0xFF60A5FA),
    violet: Color(0xFFC084FC),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
    button: Color(0xFF2563EB),
    onButton: Color(0xFFFFFFFF),
    heroStart: Color(0xFF4F46E5),
    heroEnd: Color(0xFF7C3AED),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFE0E7FF),
    heroFigure: Color(0xFFFFFFFF),
    bar: Color(0xFF111827),
    barIndicator: Color(0xFF1A2550),
    barSelected: Color(0xFF93C5FD),
    barIdle: Color(0xFF94A3B8),
    strip: Color(0xFF131A2C),
    glass: true,
    glossDebt: Gloss(
      top: Color(0xFFB91C1C),
      bottom: Color(0xFF7F1D1D),
      border: Color(0xFFF87171),
      glow: Color(0x66DC2626),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
    glossCredit: Gloss(
      top: Color(0xFF166534),
      bottom: Color(0xFF0F3B22),
      border: Color(0xFF4ADE80),
      glow: Color(0x5922C55E),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
    glossZero: Gloss(
      top: Color(0xFF23262E),
      bottom: Color(0xFF0B0B0F),
      border: Color(0xFF6B7280),
      glow: Color(0x99000000),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFF1F5F9),
      sheen: 0.18,
    ),
    glossHero: Gloss(
      top: Color(0xFF4F46E5),
      bottom: Color(0xFF5B21B6),
      border: Color(0xFF818CF8),
      glow: Color(0x664F46E5),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
    glossBlue: Gloss(
      top: Color(0xFF1D4ED8),
      bottom: Color(0xFF172554),
      border: Color(0xFF60A5FA),
      glow: Color(0x592563EB),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
    glossViolet: Gloss(
      top: Color(0xFF6D28D9),
      bottom: Color(0xFF3B0764),
      border: Color(0xFFC084FC),
      glow: Color(0x597C3AED),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
    glossGreen: Gloss(
      top: Color(0xFF166534),
      bottom: Color(0xFF052E16),
      border: Color(0xFF4ADE80),
      glow: Color(0x5916A34A),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
    glossGrey: Gloss(
      top: Color(0xFF334155),
      bottom: Color(0xFF0F172A),
      border: Color(0xFF94A3B8),
      glow: Color(0x59000000),
      ink: Color(0xFFFFFFFF),
      amount: Color(0xFFFFFFFF),
      sheen: 0.14,
    ),
  );

  LinearGradient get hero => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [heroStart, heroEnd],
  );

  /// Soft shadow under cards. Light mode only; glass cards rely on borders.
  List<BoxShadow> get cardShadow => glass
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  /// Icon square fill for [tint].
  Color iconWell(Color tint) => tint.withValues(alpha: glass ? 0.18 : 0.10);

  @override
  AppLook copyWith() => this;

  @override
  AppLook lerp(ThemeExtension<AppLook>? other, double t) =>
      other is AppLook && t >= 0.5 ? other : this;
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>()!;
  AppSidebarPalette get sidebarPalette =>
      Theme.of(this).extension<AppSidebarPalette>()!;
  AppTextExtras get textExtras => Theme.of(this).extension<AppTextExtras>()!;
  AppLook get look => Theme.of(this).extension<AppLook>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  List<BoxShadow> softShadow() => look.cardShadow;
}
