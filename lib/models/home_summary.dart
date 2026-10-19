import 'package:flutter_api_layer/api_layer.dart';

/// Fields the home shell may render. Copied from the server profile and the
/// permission list the server returned. Nothing here is calculated.
class HomeSummary {
  const HomeSummary({
    required this.displayName,
    required this.role,
    required this.mustChangePassword,
    required this.sections,
  });

  final String displayName;
  final String role;
  final bool mustChangePassword;
  final List<SectionKey> sections;

  factory HomeSummary.fromServer({
    required UserProfile profile,
    required List<SectionKey> sections,
  }) {
    return HomeSummary(
      displayName: profile.displayName,
      role: profile.role,
      mustChangePassword: profile.mustChangePassword,
      sections: List<SectionKey>.unmodifiable(sections),
    );
  }
}
