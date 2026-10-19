import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/core/permissions/permission_codes.dart';
import 'package:flutter_api_layer/core/permissions/permission_service.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/repositories/reports_repository.dart';

void main() {
  test(
      'employee: write needs BOTH *.write and sectionAccess=manage; read needs *.read and != none',
      () {
    final p = PermissionService()
      ..applyFromServer(
        [
          'debts.read',
          'debts.write',
          'companies.read',
          'companies.write',
          'treasury.read',
          'masraweya.write',
          'collections.read',
          'collections.write',
          'purchases.read',
          'purchases.finalize'
        ],
        role: 'employee',
        sectionAccess: {
          'customerDebts': 'manage',
          'companyDebts': 'read',
          'treasury': 'none',
          'masraweya': 'manage',
          'purchases': 'manage'
        },
      );
    expect(p.role, AccountRole.employee);
    expect(p.fullAccess, isFalse);
    expect(p.canRead(SectionKey.customers), isTrue);
    expect(p.canWrite(SectionKey.customers), isTrue);
    expect(p.canRead(SectionKey.companies), isTrue);
    expect(p.canWrite(SectionKey.companies), isFalse);
    expect(p.canRead(SectionKey.treasury), isFalse);
    expect(p.canRead(SectionKey.masraweya), isFalse);
    expect(p.canWrite(SectionKey.masraweya), isFalse); // write without read
    expect(p.canRead(SectionKey.reports), isFalse);
    expect(p.canWrite(SectionKey.collections),
        isTrue); // not in sectionAccess: codes only
    expect(p.canFinalizePurchases, isFalse);
    expect(p.canDo(ManagementAction.collectionsDecide), isFalse);
    expect(
        p.canOnRecord(action: 'edit', section: SectionKey.companies), isFalse);
    expect(
        p.canOnRecord(
            action: 'edit',
            allowedActions: ['edit'],
            section: SectionKey.companies),
        isTrue);
    expect(p.visibleSections, [
      SectionKey.customers,
      SectionKey.collections,
      SectionKey.companies,
      SectionKey.purchases
    ]);
  });

  test(
      'admin with empty lists (real server today) -> role flag grants everything',
      () {
    final p = PermissionService()..applyFromServer(const [], role: 'admin');
    expect(p.role, AccountRole.admin);
    expect(p.fullAccess, isTrue);
    expect(SectionKey.values.where((s) => s.write != null).every(p.canWrite),
        isTrue);
    expect(p.canWrite(SectionKey.reports), isFalse); // read-only section
    expect(ManagementAction.values.every(p.canDo), isTrue);
  });

  test('precedence: explicit fullAccess beats role; explicit lists beat role',
      () {
    final flagFalse = PermissionService()
      ..applyFromServer(const [], role: 'admin', fullAccess: false);
    expect(flagFalse.visibleSections, isEmpty);

    final flagTrue = PermissionService()
      ..applyFromServer(const [], role: 'employee', fullAccess: true);
    expect(
        SectionKey.values
            .where((s) => s.write != null)
            .every(flagTrue.canWrite),
        isTrue);

    final limitedAdmin = PermissionService()
      ..applyFromServer(
          ['collections.read', 'collections.decide', 'debts.read'],
          role: 'admin',
          sectionAccess: {'customerDebts': 'read'});
    expect(limitedAdmin.fullAccess, isFalse);
    expect(limitedAdmin.canRead(SectionKey.customers), isTrue);
    expect(limitedAdmin.canWrite(SectionKey.customers), isFalse);
    expect(limitedAdmin.canRead(SectionKey.treasury), isFalse);
    expect(limitedAdmin.canDo(ManagementAction.collectionsDecide), isTrue);
    expect(
        limitedAdmin.canDo(ManagementAction.collectionsCashReceived), isFalse);

    final adminAccessOnly = PermissionService()
      ..applyFromServer(const [],
          role: 'admin', sectionAccess: {'treasury': 'manage'});
    expect(
        adminAccessOnly.fullAccess, isFalse); // non-empty sectionAccess applies
    expect(adminAccessOnly.canRead(SectionKey.treasury),
        isFalse); // no treasury.read code
  });

  test('role match is exact; unknown or missing role grants nothing', () {
    for (final r in <String?>[
      'Admin',
      'ADMIN',
      ' admin',
      'admin ',
      'administrator',
      'guest',
      '',
      null
    ]) {
      final p = PermissionService()
        ..applyFromServer(['debts.read', 'debts.write', 'collections.read'],
            role: r, sectionAccess: {'customerDebts': 'manage'});
      expect(p.role, AccountRole.unknown, reason: 'role=$r');
      expect(p.visibleSections, isEmpty, reason: 'role=$r');
      expect(p.fullAccess, isFalse, reason: 'role=$r');
    }
  });

  test(
      'employee with codes but no sectionAccess fails closed (except collections)',
      () {
    final p = PermissionService()
      ..applyFromServer(['debts.read', 'debts.write', 'collections.read'],
          role: 'employee');
    expect(p.visibleSections, [SectionKey.collections]);
  });

  test('write requires the section read code as well as manage', () {
    final writeOnly = PermissionService()
      ..applyFromServer(
        ['debts.write'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'manage'},
      );
    expect(writeOnly.canRead(SectionKey.customers), isFalse);
    expect(writeOnly.canWrite(SectionKey.customers), isFalse);

    final both = PermissionService()
      ..applyFromServer(
        ['debts.read', 'debts.write'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'manage'},
      );
    expect(both.canWrite(SectionKey.customers), isTrue);

    final readLevel = PermissionService()
      ..applyFromServer(
        ['debts.read', 'debts.write'],
        role: 'employee',
        sectionAccess: {'customerDebts': 'read'},
      );
    expect(readLevel.canRead(SectionKey.customers), isTrue);
    expect(readLevel.canWrite(SectionKey.customers), isFalse);
  });

  test('financial ledger and statement PDF are full-access only', () async {
    final settingsOnly = PermissionService()
      ..applyFromServer(
        ['settings.manage', 'reports.read'],
        role: 'admin',
        sectionAccess: {'reports': 'manage'},
      );
    expect(settingsOnly.fullAccess, isFalse);
    expect(settingsOnly.canDo(ManagementAction.settingsManage), isTrue);
    expect(settingsOnly.canReadPrivilegedFinance, isFalse);
    final blocked = RemoteReportsRepository(
      FakeApiClient(latency: Duration.zero),
      settingsOnly,
    );
    expect(blocked.financialLedger(), throwsA(isA<ForbiddenException>()));
    expect(blocked.statementPdf(), throwsA(isA<ForbiddenException>()));

    final full = PermissionService()..applyFromServer(const [], role: 'admin');
    expect(full.canReadPrivilegedFinance, isTrue);
    expect(
      PermissionService()
          .canReadPrivilegedFinance,
      isFalse,
    );
  });

  test(
      'no role comparison anywhere outside lib/core/permissions/permission_service.dart',
      () {
    final allowed = 'lib/core/permissions/permission_service.dart'
        .replaceAll('/', Platform.pathSeparator);
    final comparison = RegExp(
      r'''\brole\b\s*(==|!=)|(==|!=)\s*\w*\.?role\b|\.role\s*\.\s*(contains|startsWith|endsWith|toLowerCase|compareTo)|'''
      r'''(==|!=)\s*['"](admin|employee)['"]|['"](admin|employee)['"]\s*(==|!=)|isAdmin|adminRoleValue|employeeRoleValue''',
    );
    final offenders = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith(allowed)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue; // comments may describe the rule
        if (comparison.hasMatch(line)) {
          offenders.add('${f.path}:${i + 1}: $line');
        }
      }
    }
    expect(offenders, isEmpty);
    // The guard itself must catch typical comparisons.
    for (final bad in [
      "if (user.role == 'admin') {}",
      "final a = 'admin' == r;",
      'x.role.startsWith("ad")',
      'bool get isAdmin => true;'
    ]) {
      expect(comparison.hasMatch(bad), isTrue, reason: bad);
    }
    expect(comparison.hasMatch("'role': admin ? 'admin' : 'employee',"),
        isFalse); // fake data, not a comparison
  });
}
