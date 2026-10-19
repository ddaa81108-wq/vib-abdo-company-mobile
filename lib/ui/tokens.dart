import 'package:flutter/widgets.dart';

/// Breakpoints from the UI spec: 360 / 560 / 900 / 1100.
abstract final class AppBreakpoints {
  static const phoneSmall = 360.0;
  static const phone = 560.0;
  static const tablet = 900.0;
  static const wide = 1100.0;

  static bool isPhone(double width) => width <= phone;
  static bool isRail(double width) => width > phone && width <= tablet;
  static bool isPanel(double width) => width > tablet;

  static int cardColumns(double width) {
    if (width <= phoneSmall) return 1;
    if (width <= phone) return 2;
    if (width <= tablet) return 3;
    if (width < wide) return 4;
    return 6;
  }
}

abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 14.0;
  static const xxl = 20.0;
}

abstract final class AppRadii {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const card = 13.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const pill = 999.0;
}

EdgeInsetsDirectional pagePadding(double width) => EdgeInsetsDirectional.all(
  width <= AppBreakpoints.phone ? AppSpacing.lg : AppSpacing.xl,
);
