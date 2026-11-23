import 'package:flutter/material.dart';

import 'operations/operations_home.dart';
export 'home_layout.dart';
export 'operations/home_tile.dart' show HomeTile;

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});
  static const screenKey = Key('home-dashboard');
  static const retryKey = Key('home-retry');
  static const settingsTileKey = Key('home-tile-settings');
  @override
  Widget build(BuildContext context) =>
      const OperationsHome(screenKey: screenKey, settingsKey: settingsTileKey);
}
