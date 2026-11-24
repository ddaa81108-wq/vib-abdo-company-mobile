import 'package:flutter/material.dart';

/// The approved ceramic finish belongs to home only, not financial cards.
abstract final class HomeCeramicStyle {
  static const edge = Color(0xFFB99345);
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      dark(context) ? const Color(0xFF0B1020) : const Color(0xFFF5F5F3);
  static Color bar(BuildContext context) =>
      dark(context) ? const Color(0xFF111B2A) : Colors.white;
  static Color ink(BuildContext context) =>
      dark(context) ? const Color(0xFFF2F5FA) : const Color(0xFF17253A);
  static List<Color> surfaces(BuildContext context) => dark(context)
      ? const [
          Color(0xFF203248),
          Color(0xFF17263A),
          Color(0xFF112033),
          Color(0xFF1E3047),
        ]
      : const [
          Colors.white,
          Color(0xFFFAFAF8),
          Color(0xFFF0F0ED),
          Colors.white,
        ];
}
