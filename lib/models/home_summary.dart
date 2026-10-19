import 'package:flutter_api_layer/api_layer.dart';

/// Fields the home shell may render. Section visibility and write controls
/// come from [PermissionService], already decided. Nothing here is calculated.
class HomeSummary {
  const HomeSummary({
    required this.displayName,
    required this.accountRole,
    required this.mustChangePassword,
    required this.sections,
    required this.writableSections,
  });

  final String displayName;
  final AccountRole accountRole;
  final bool mustChangePassword;
  final List<SectionKey> sections;
  final List<SectionKey> writableSections;

  factory HomeSummary.fromServer({
    required UserProfile profile,
    required PermissionService permissions,
  }) {
    return HomeSummary(
      displayName: profile.displayName,
      accountRole: permissions.accountRole,
      mustChangePassword: profile.mustChangePassword,
      sections: List<SectionKey>.unmodifiable(permissions.readableSections),
      writableSections: List<SectionKey>.unmodifiable(
        permissions.writableSections,
      ),
    );
  }
}
