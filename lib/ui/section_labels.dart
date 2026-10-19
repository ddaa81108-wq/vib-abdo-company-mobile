import 'package:flutter_api_layer/api_layer.dart';

import 'strings.dart';

/// Presentation labels only. Visibility is decided by [PermissionService], not by this map.
String sectionLabel(SectionKey section) => switch (section) {
  SectionKey.customers => 'ديون العملاء',
  SectionKey.collections => 'استلامات الديون',
  SectionKey.companies => 'ديون الشركات',
  SectionKey.libyanDeposits => 'أمانات ليبية',
  SectionKey.egyptianDeposits => 'أمانات مصرية',
  SectionKey.masraweya => 'المصراوية',
  SectionKey.purchases => 'المشتريات',
  SectionKey.treasury => 'الخزينة',
  SectionKey.reports => 'التقارير',
};

/// Label for a management action the permission service already allowed.
String actionLabel(ManagementAction action) => switch (action) {
  ManagementAction.collectionsAssign => 'إسناد استلام',
  ManagementAction.collectionsDecide => 'اعتماد أو رفض',
  ManagementAction.collectionsCashReceived => 'استلام نقدي',
  ManagementAction.collectionsCloseDay => 'إقفال اليوم',
  ManagementAction.payrollManage => 'المرتبات',
  ManagementAction.customerZeroReview => 'مراجعة التصفير',
  ManagementAction.accountRequestsDecide => 'طلبات الحسابات',
  ManagementAction.settingsManage => 'الإعدادات',
};

/// Label for the role the permission service already classified.
String roleLabel(AccountRole role) => switch (role) {
  AccountRole.admin => AppStrings.roleAdmin,
  AccountRole.employee => AppStrings.roleEmployee,
  AccountRole.unknown => AppStrings.roleUnknown,
};
