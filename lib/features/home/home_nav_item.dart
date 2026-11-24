import 'package:flutter/material.dart';

class NavItem {
  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
    this.shortLabel,
  });
  final String id, label, path;

  /// The full label remains the accessibility name.
  final String? shortLabel;
  final IconData icon;
}
