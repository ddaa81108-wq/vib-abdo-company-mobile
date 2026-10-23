@Tags(['permissions-negative'])
library;

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// P-08 negative cases. A missing `sectionAccess` is not the same as a
/// broken one: only null widens nothing, and a non-object denies by default.
void main() {
  Map<String, Object?> user({Object? sectionAccess, bool include = true}) {
    return {
      'id': 'u_test',
      'username': 'person@example.invalid',
      'displayName': 'شخص تجريبي',
      'role': 'employee',
      'permissions': ['debts.read', 'debts.write', 'collections.read'],
      if (include) 'sectionAccess': sectionAccess,
      'mustChangePassword': false,
    };
  }

  test('parser keeps absent and null, and rejects a non-object', () {
    expect(UserProfile.fromJson(user(include: false)).sectionAccess, isNull);
    expect(
        UserProfile.fromJson(user(sectionAccess: null)).sectionAccess, isNull);
    expect(
        UserProfile.fromJson(user(sectionAccess: {})).sectionAccess, isEmpty);
    expect(
      UserProfile.fromJson(user(sectionAccess: {'customerDebts': 'read'}))
          .sectionAccess,
      {'customerDebts': 'read'},
    );
    for (final raw in <Object>[
      'read',
      ['read'],
      1
    ]) {
      expect(
        UserProfile.fromJson(user(sectionAccess: raw)).sectionAccess,
        isEmpty,
        reason: '$raw',
      );
      expect(sectionAccessFromJson(raw), isEmpty, reason: '$raw');
    }
    expect(sectionAccessFromJson(null), isNull);
  });

  test('a malformed sectionAccess denies keyed sections and keeps collections',
      () {
    for (final raw in <Object>[
      'manage',
      <String>['manage'],
      3
    ]) {
      final profile = UserProfile.fromJson(user(sectionAccess: raw));
      final permissions = PermissionService()
        ..applyFromServer(
          profile.permissions,
          role: profile.role,
          sectionAccess: profile.sectionAccess,
        );
      expect(permissions.canRead(SectionKey.customers), isFalse,
          reason: '$raw');
      expect(permissions.canWrite(SectionKey.customers), isFalse,
          reason: '$raw');
      expect(permissions.canRead(SectionKey.collections), isTrue,
          reason: '$raw');
      expect(permissions.canWrite(SectionKey.collections), isFalse,
          reason: '$raw');
      expect(permissions.fullAccess, isFalse, reason: '$raw');
    }
  });

  test('an unknown role grants nothing even with codes and no map', () {
    final permissions = PermissionService()
      ..applyFromServer(
        const ['debts.read', 'debts.write', 'collections.read'],
        role: 'guest',
      );
    expect(permissions.role, AccountRole.unknown);
    expect(permissions.fullAccess, isFalse);
    expect(permissions.visibleSections, isEmpty);
    expect(permissions.canRead(SectionKey.customers), isFalse);
    expect(permissions.canRead(SectionKey.collections), isFalse);
  });

  test('an employee with an empty permission list and no map has no access',
      () {
    final permissions = PermissionService()
      ..applyFromServer(const [], role: 'employee');
    expect(permissions.role, AccountRole.employee);
    expect(permissions.fullAccess, isFalse);
    expect(permissions.visibleSections, isEmpty);
    expect(permissions.canViewFinancialLedger, isFalse);
    expect(permissions.canRead(SectionKey.collections), isFalse);
    expect(permissions.canWrite(SectionKey.collections), isFalse);
  });
}
