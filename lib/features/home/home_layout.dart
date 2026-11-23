import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/tokens.dart';
import '../../ui/section_labels.dart';

List<String> homeShowAllSections(
  Iterable<String> sections,
  PermissionService permissions,
) {
  final ordered = <String>[];
  for (final section in sections) {
    if (!ordered.contains(section) &&
        homeShowAllPath(section, permissions) != null) {
      ordered.add(section);
    }
  }
  return ordered;
}

SectionKey? sectionKeyFor(String section) =>
    SectionKey.values.where((key) => key.key == section).firstOrNull;
int homeCardColumns(double width, double textScale) =>
    textScale >= 1.3 ? 1 : AppBreakpoints.cardColumns(width);
int homeTileColumns(double width, double textScale) => textScale >= 1.3
    ? 1
    : width <= AppBreakpoints.phone
    ? 2
    : width <= AppBreakpoints.tablet
    ? 3
    : 4;
