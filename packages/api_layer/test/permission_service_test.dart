import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PermissionService service;

  setUp(() => service = PermissionService());

  test('unknown or missing role with empty permissions opens nothing', () {
    service.applyFromServer(role: 'guest', permissions: const []);
    expect(service.accountRole, AccountRole.unknown);
    expect(service.readableSections, isEmpty);
    expect(service.writableSections, isEmpty);
    expect(service.canRead(SectionKey.customers), isFalse);
    expect(service.canWrite(SectionKey.collections), isFalse);
    expect(service.canDo(AdminOnlyAction.collectionsCloseDay), isFalse);

    service.applyFromServer(
      role: '',
      permissions: const ['debts.read'],
      sectionAccess: const {'customers': 'manage'},
    );
    expect(service.readableSections, isEmpty);
    expect(service.writableSections, isEmpty);
  });

  test('employee with a read-only permission cannot write', () {
    service.applyFromServer(
      role: 'employee',
      permissions: const ['debts.read'],
      sectionAccess: const {'customers': 'view'},
    );
    expect(service.canRead(SectionKey.customers), isTrue);
    expect(service.canWrite(SectionKey.customers), isFalse);
    expect(service.writableSections, isEmpty);

    service.applyFromServer(
      role: 'employee',
      permissions: const ['collections.read', 'collections.write'],
      sectionAccess: const {'collections': 'view'},
    );
    expect(service.canRead(SectionKey.collections), isTrue);
    expect(service.canWrite(SectionKey.collections), isFalse);
  });

  test('employee without sectionAccess for a section does not see it', () {
    service.applyFromServer(
      role: 'employee',
      permissions: const ['debts.read', 'treasury.read'],
      sectionAccess: const {'customers': 'view'},
    );
    expect(service.readableSections, [SectionKey.customers]);
    expect(service.canRead(SectionKey.treasury), isFalse);
    expect(service.canRead(SectionKey.collections), isFalse);
  });

  test('admin with an explicit permission list is limited to that list', () {
    service.applyFromServer(
      role: 'admin',
      permissions: const ['collections.read'],
      sectionAccess: const {'collections': 'view', 'treasury': 'manage'},
    );
    expect(service.accountRole, AccountRole.admin);
    expect(service.readableSections, [SectionKey.collections]);
    expect(service.canWrite(SectionKey.collections), isFalse);
    expect(service.canRead(SectionKey.treasury), isFalse);
    expect(service.canRead(SectionKey.customers), isFalse);
    expect(service.canDo(AdminOnlyAction.payrollManage), isFalse);
  });

  test('admin with an empty permission list keeps the unrestricted flag', () {
    service.applyFromServer(role: 'admin', permissions: const []);
    expect(service.canRead(SectionKey.treasury), isTrue);
    expect(service.canWrite(SectionKey.purchases), isTrue);
    expect(service.canWrite(SectionKey.reports), isFalse);
    expect(service.canDo(AdminOnlyAction.collectionsDecide), isTrue);
  });

  test('profile stores role, permissions, and sectionAccess without deciding',
      () {
    final me = MeResponse.fromData({
      'user': {
        'username': 'person@example.invalid',
        'displayName': 'شخص تجريبي',
        'role': 'employee',
        'permissions': ['debts.read'],
        'sectionAccess': {'customers': 'view'},
        'mustChangePassword': false,
      },
    });
    expect(me.user.role, 'employee');
    expect(me.user.permissions, ['debts.read']);
    expect(me.user.sectionAccess, {'customers': 'view'});
  });
}
