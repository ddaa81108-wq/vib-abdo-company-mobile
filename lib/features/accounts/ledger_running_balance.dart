import 'package:flutter_api_layer/api_layer.dart';

/// The website's ledger rules, mirrored for display (Ali, 2026-11-03).
///
/// Source: staging bundle `assets/LedgerWorkspace-BQxJagtI.js`, read
/// 2026-11-03:
///
/// ```js
/// r.items.filter(i=>i.status!=="reversed").map(i=> ... )
/// ```
///
/// `reversed` (cancelled) rows are not drawn. The server keeps them for the
/// audit trail; nothing is deleted. `corrected` rows are still drawn.

/// The website draws every row except `reversed` ones.
bool websiteShowsRow(LedgerEntryDto entry) => entry.status != 'reversed';
