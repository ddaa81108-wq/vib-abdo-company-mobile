import 'dart:async';

import 'package:flutter_api_layer/data/fake/fake_api_client.dart';

/// Scripted server pages for UI tests; matching itself is verified against
/// real server query outputs in account_search_parity_test.dart.
void scriptAccountSearch(
  FakeApiClient fake,
  List<Map<String, dynamic>> rows, {
  Completer<void>? pause,
}) {
  fake.accountQueryPage = (section, query, cursor) async {
    final items = [
      for (final row in rows)
        if (row['section'] == section) {...row},
    ];
    if (pause != null) await pause.future;
    return {'items': items, 'nextCursor': null, 'summary': <String, dynamic>{}};
  };
}
