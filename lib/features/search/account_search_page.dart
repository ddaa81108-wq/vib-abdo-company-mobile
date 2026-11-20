import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';

/// Each section owns its cursor. A full customer page must never hide deposits.
class AccountSearchPage {
  const AccountSearchPage({required this.items, required this.nextCursors});

  final List<GlobalAccountHit> items;
  final Map<AccountSection, String> nextCursors;
}

/// Both scopes use exactly the same server-side name/phone matching.
/// This only reads pages: no client matching, totals, or currency conversion.
Future<AccountSearchPage> readAccountSearchPage(
  AccountsRepository repository, {
  required String query,
  required Iterable<AccountSection> sections,
  Map<AccountSection, String>? after,
}) async {
  final pages = await Future.wait([
    for (final section in sections)
      if (after == null || after.containsKey(section))
        repository
            .list(section, q: query, cursor: after?[section], limit: 30)
            .then((page) => (section, page)),
  ]);
  return AccountSearchPage(
    items: [
      for (final (section, page) in pages)
        for (final card in page.page.items)
          GlobalAccountHit(
            section: section,
            id: card.id,
            name: card.name,
            phone: card.phone,
            balanceUnits: card.balanceUnits,
            currency: card.currency,
            activeAssigneeName: card.activeAssigneeName,
          ),
    ],
    nextCursors: {
      for (final (section, page) in pages)
        if (page.page.nextCursor case final String cursor)
          if (cursor.isNotEmpty && cursor != after?[section]) section: cursor,
    },
  );
}
