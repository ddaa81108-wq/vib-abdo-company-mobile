import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final colors = dark ? AppColors.dark : AppColors.light;
  final status = dark ? AppStatusColors.dark : AppStatusColors.light;
  // Light login is gold on a pale canvas, so that theme's base is darker.
  // Dark mode keeps the bright gold. The sidebar word uses bright.
  final sidebar = dark
      ? AppSidebarPalette.gold
      : AppSidebarPalette.gold.copyWith(base: const Color(0xFF7C6100));
  final extras = AppTextExtras.standard;
  final base = cairo(13, 500, color: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    fontFamily: 'Cairo',
    shadowColor: dark ? const Color(0x00000000) : scheme.shadow,
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
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: dark ? const Color(0x00000000) : scheme.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: dark ? scheme.outline : scheme.outlineVariant),
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: cairo(16, 700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.sidebarBg,
      indicatorColor: sidebar.glow,
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
      backgroundColor: colors.sidebarBg,
      contentTextStyle: cairo(13, 600, color: sidebar.shine),
    ),
    extensions: [colors, status, sidebar, extras],
  );
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF175F50),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE6F2ED),
  onPrimaryContainer: Color(0xFF0F453A),
  secondary: Color(0xFFC79232),
  onSecondary: Color(0xFF24180E),
  secondaryContainer: Color(0xFFFFF6E0),
  onSecondaryContainer: Color(0xFF24180E),
  tertiary: Color(0xFF175F50),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFF8D2C2C),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFF0F0),
  onErrorContainer: Color(0xFF8D2C2C),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF172723),
  onSurfaceVariant: Color(0xFF6D7C77),
  outline: Color(0xFFD5DEE9),
  outlineVariant: Color(0xFFE8EDF3),
  shadow: Color(0x12172723),
  scrim: Color(0x8F0D211E),
  inverseSurface: Color(0xFF172333),
  onInverseSurface: Color(0xFFEDF2FA),
  inversePrimary: Color(0xFF247763),
  surfaceTint: Color(0xFF175F50),
  surfaceContainerLowest: Color(0xFFE5EDF6),
  surfaceContainerLow: Color(0xFFF6F8FB),
  surfaceContainer: Color(0xFFF6F8FB),
  surfaceContainerHigh: Color(0xFFE7EDF4),
  surfaceContainerHighest: Color(0xFFE7EDF4),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF36B496),
  onPrimary: Color(0xFF041510),
  primaryContainer: Color(0xFF193B37),
  onPrimaryContainer: Color(0xFFEDF2FA),
  secondary: Color(0xFFD8BC7E),
  onSecondary: Color(0xFF24180E),
  secondaryContainer: Color(0xFF3A2E16),
  onSecondaryContainer: Color(0xFFFFF6E0),
  tertiary: Color(0xFF36B496),
  onTertiary: Color(0xFF041510),
  error: Color(0xFFFFB1B7),
  onError: Color(0xFF3A1216),
  errorContainer: Color(0xFF3A2430),
  onErrorContainer: Color(0xFFFFB1B7),
  surface: Color(0xFF172333),
  onSurface: Color(0xFFEDF2FA),
  onSurfaceVariant: Color(0xFFACBBCE),
  outline: Color(0xFF36465B),
  outlineVariant: Color(0xFF27364A),
  shadow: Color(0x40000000),
  scrim: Color(0xCC050B16),
  inverseSurface: Color(0xFFEDF2FA),
  onInverseSurface: Color(0xFF172333),
  inversePrimary: Color(0xFF175F50),
  surfaceTint: Color(0xFF36B496),
  surfaceContainerLowest: Color(0xFF0D1522),
  surfaceContainerLow: Color(0xFF1C2A3D),
  surfaceContainer: Color(0xFF1C2A3D),
  surfaceContainerHigh: Color(0xFF25354A),
  surfaceContainerHighest: Color(0xFF25354A),
);

TextStyle cairo(
  double size,
  double weight, {
  Color? color,
  double height = 1.35,
}) {
  return TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    height: height,
    color: color,
    fontWeight: _weight(weight),
    fontVariations: [FontVariation('wght', weight)],
  );
}

TextStyle mono(double size, FontWeight weight, {Color? color}) {
  return TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: size,
    height: 1.3,
    color: color,
    fontWeight: weight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

FontWeight _weight(double weight) {
  if (weight >= 800) return FontWeight.w800;
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
    label: Color(0xFF344640),
    sidebarBg: Color(0xFF102A26),
    sidebarMuted: Color(0xFFA9C0B8),
    noteBg: Color(0xFFEDF5F1),
    noteLine: Color(0xFFD4E6DE),
    noteText: Color(0xFF4C675F),
    success: Color(0xFF17624D),
    successBg: Color(0xFFEDF9F4),
    successLine: Color(0xFFC6E9DC),
    overlay: Color(0x8F0D211E),
    fieldBg: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    label: Color(0xFFDCE5F2),
    sidebarBg: Color(0xFF101B2A),
    sidebarMuted: Color(0xFFB1C0D3),
    noteBg: Color(0xFF182F39),
    noteLine: Color(0xFF345263),
    noteText: Color(0xFFC1DCE4),
    success: Color(0xFF92DFC2),
    successBg: Color(0xFF19392F),
    successLine: Color(0xFF386D59),
    overlay: Color(0xCC050B16),
    fieldBg: Color(0xFF111D2C),
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

  static const gold = AppSidebarPalette(
    tint: Color(0xFF191303),
    edge: Color(0xFFD5A71E),
    line: Color(0xFF624B10),
    light: Color(0xFFFFE477),
    shine: Color(0xFFFFFDE0),
    bright: Color(0xFFFFDB35),
    base: Color(0xFFEAB600),
    ink: Color(0xFF24180E),
    glow: Color(0x66FFD52B),
    glowSoft: Color(0x12FFD52B),
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
    debtText: Color(0xFFA54339),
    creditText: Color(0xFF23705D),
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
      Color(0xFFE7F0FA),
      Color(0xFFF3EFE4),
      Color(0xFFE7F2EC),
      Color(0xFFF6EBE3),
      Color(0xFFEEEAF6),
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
    debtText: Color(0xFFFFB1B7),
    creditText: Color(0xFF92DFC2),
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
      Color(0xFF1A2740),
      Color(0xFF2A261C),
      Color(0xFF1A2C24),
      Color(0xFF2C221C),
      Color(0xFF241E30),
    ],
    neutralCard: Color(0xFF172333),
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

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>()!;
  AppSidebarPalette get sidebarPalette =>
      Theme.of(this).extension<AppSidebarPalette>()!;
  AppTextExtras get textExtras => Theme.of(this).extension<AppTextExtras>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  List<BoxShadow> softShadow() {
    if (isDark) return const [];
    return const [
      BoxShadow(color: Color(0x12172723), blurRadius: 12, offset: Offset(0, 3)),
    ];
  }
}
