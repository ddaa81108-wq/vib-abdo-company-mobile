import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import 'strings.dart';

/// Presentation labels only. Visibility is decided by [PermissionService].
String sectionLabel(SectionKey section) => switch (section) {
  SectionKey.customers => 'ديون العملاء',
  SectionKey.collections => 'استلامات الديون',
  SectionKey.companies => 'ديون الشركات',
  SectionKey.libyanDeposits => 'أمانات ليبية',
  SectionKey.egyptianDeposits => 'أمانات مصرية',
  SectionKey.masraweya => 'صفحة المصراوية',
  SectionKey.purchases => 'المشتريات',
  SectionKey.treasury => 'الخزينة',
  SectionKey.reports => 'التقارير الذكية',
};

IconData sectionIcon(SectionKey section) => switch (section) {
  SectionKey.customers => Icons.person_outline,
  SectionKey.collections => Icons.payments_outlined,
  SectionKey.companies => Icons.apartment_outlined,
  SectionKey.libyanDeposits => Icons.account_balance_wallet_outlined,
  SectionKey.egyptianDeposits => Icons.currency_exchange,
  SectionKey.masraweya => Icons.menu_book_outlined,
  SectionKey.purchases => Icons.shopping_bag_outlined,
  SectionKey.treasury => Icons.account_balance_outlined,
  SectionKey.reports => Icons.insights_outlined,
};

String sectionPath(SectionKey section) => '/${section.key}';

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

String actionPath(ManagementAction action) => switch (action) {
  ManagementAction.collectionsAssign => sectionPath(SectionKey.customers),
  ManagementAction.collectionsDecide ||
  ManagementAction.collectionsCashReceived ||
  ManagementAction.collectionsCloseDay ||
  ManagementAction.payrollManage => sectionPath(SectionKey.collections),
  ManagementAction.customerZeroReview => sectionPath(SectionKey.customers),
  ManagementAction.accountRequestsDecide ||
  ManagementAction.settingsManage => '/settings',
};

/// Label for the role the permission service already classified.
String roleLabel(AccountRole role) => switch (role) {
  AccountRole.admin => AppStrings.roleAdmin,
  AccountRole.employee => AppStrings.roleEmployee,
  AccountRole.unknown => AppStrings.roleUnknown,
};
