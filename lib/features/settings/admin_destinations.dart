import 'package:flutter/material.dart';

import '../../ui/strings.dart';

/// Admin settings areas that still have no server feed.
///
/// The fake client and the app providers do not return employees, an audit
/// log, or an operations status. Each entry is an empty screen until that
/// data exists. Removing an entry here hides its tile, its route, and its
/// shell title together. Ali has not decided whether these stay.
const adminDestinations = <AdminDestination>[
  AdminDestination(
    id: 'employees',
    title: AppStrings.employeesTile,
    emptyMessage: AppStrings.employeesEmpty,
    icon: Icons.groups_outlined,
  ),
  AdminDestination(
    id: 'audit',
    title: AppStrings.auditTile,
    emptyMessage: AppStrings.auditEmpty,
    icon: Icons.fact_check_outlined,
  ),
  AdminDestination(
    id: 'operations',
    title: AppStrings.operationsTile,
    emptyMessage: AppStrings.operationsEmpty,
    icon: Icons.monitor_heart_outlined,
  ),
];

/// The destination that owns [location], if it is one of [adminDestinations].
AdminDestination? adminDestinationFor(String location) {
  for (final destination in adminDestinations) {
    if (location == destination.path ||
        location.startsWith('${destination.path}/')) {
      return destination;
    }
  }
  return null;
}

class AdminDestination {
  const AdminDestination({
    required this.id,
    required this.title,
    required this.emptyMessage,
    required this.icon,
  });

  final String id;
  final String title;
  final String emptyMessage;
  final IconData icon;

  String get path => '/settings/$id';

  Key get tileKey => Key('settings-link-$id');

  Key get screenKey => Key('screen-settings-$id');
}
