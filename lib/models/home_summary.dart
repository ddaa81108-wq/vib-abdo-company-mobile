import 'package:flutter_api_layer/api_layer.dart';

/// Fields the home shell may render. Section visibility, write controls, and
/// management actions come from [PermissionService]. Nothing here is calculated.
class HomeSummary {
  const HomeSummary({
    required this.displayName,
    required this.role,
    required this.mustChangePassword,
    required this.sections,
    required this.writableSections,
    required this.actions,
  });

  final String displayName;
  final AccountRole role;
  final bool mustChangePassword;
  final List<SectionKey> sections;
  final List<SectionKey> writableSections;
  final List<ManagementAction> actions;

  factory HomeSummary.fromServer({
    required UserProfile profile,
    required PermissionService permissions,
  }) {
    final sections = permissions.visibleSections;
    return HomeSummary(
      displayName: profile.displayName,
      role: permissions.role,
      mustChangePassword: profile.mustChangePassword,
      sections: List<SectionKey>.unmodifiable(sections),
      writableSections: List<SectionKey>.unmodifiable([
        for (final section in sections)
          if (permissions.canWrite(section)) section,
      ]),
      actions: List<ManagementAction>.unmodifiable([
        for (final action in ManagementAction.values)
          if (permissions.canDo(action)) action,
      ]),
    );
  }
}

/// Home cards and old-debt rows are shown only when [PermissionService] allows
/// that server section. The server list is not filtered by any other rule.
bool sectionIsReadable(String section, PermissionService permissions) {
  for (final key in SectionKey.values) {
    if (key.key == section) return permissions.canRead(key);
  }
  return false;
}
