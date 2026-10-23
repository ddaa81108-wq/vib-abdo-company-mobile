import 'package:flutter_api_layer/api_layer.dart';

/// Server section keys for an Egyptian-deposit account.
///
/// The contract uses `egyptian_deposits`. The app's own section path uses a
/// hyphen. Either spelling is the paused link. This is not a currency check.
const egyptianDepositSectionKeys = {'egyptian_deposits', 'egyptian-deposits'};

/// True when the server sent an Egyptian-deposit section on a link candidate.
bool isEgyptianDepositSection(Object? sectionKey) {
  if (sectionKey == null) return false;
  return egyptianDepositSectionKeys.contains('$sectionKey');
}

/// True when this candidate must not be linked. A missing section stays
/// linkable: that is the existing LYD id entry.
bool isPausedEgyptianLink(Json? candidate) {
  if (candidate == null) return false;
  return isEgyptianDepositSection(candidate['sectionKey']);
}

/// Candidates the picker may offer. Egyptian-deposit rows are omitted.
List<Json> linkableCandidates(List<Json> items) {
  return [
    for (final item in items)
      if (!isPausedEgyptianLink(item)) item,
  ];
}

/// Remembers section keys the server already sent, keyed by candidate id.
void rememberLinkCandidates(Map<String, Json> seen, List<Json> items) {
  for (final item in items) {
    final id = item['id'];
    if (id == null) continue;
    final key = '$id';
    final previous = seen[key];
    // A later row that drops the section does not clear a pause already seen.
    if (isPausedEgyptianLink(previous) && !isPausedEgyptianLink(item)) {
      continue;
    }
    seen[key] = item;
  }
}
