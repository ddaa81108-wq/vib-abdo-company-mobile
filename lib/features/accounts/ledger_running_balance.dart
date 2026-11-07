import 'package:flutter_api_layer/api_layer.dart';

/// The website's ledger rules, mirrored for display (Ali, 2026-11-03).
///
/// Source: staging bundle `assets/LedgerWorkspace-BQxJagtI.js`, read
/// 2026-11-03:
///
/// ```js
/// function ve(e){let r=e.pageOpeningBalanceUnits;const s=new Map;
///   return[...e.items].sort((l,n)=>l.sequence-n.sequence).forEach(l=>{
///     l.status==="posted"&&(r+=l.type==="debt"?l.amountUnits:-l.amountUnits),
///     s.set(l.id,r)}),s}
/// ...
/// r.items.filter(i=>i.status!=="reversed").map(i=> ... balanceAfter:y.get(i.id)??0 ...)
/// ```
///
/// With an older page loaded the website (`Dashboard-CkXp6HDi.js`, `If`)
/// takes the older page's `pageOpeningBalanceUnits` and puts its items
/// before the newer ones, then runs `ve` over the whole list.
///
/// Only `posted` rows move the balance. `corrected` rows are drawn (the
/// website labels them « — مصححة») but do not move it. `reversed` rows
/// are not drawn; they still get a value in the map, as on the website.
/// Integer minor units only.

/// The website draws every row except `reversed` ones.
bool websiteShowsRow(LedgerEntryDto entry) => entry.status != 'reversed';

/// The signed effect of one row on the running balance, or null when a
/// counted row has no valid integer amount (then nothing is shown).
({bool ok, int delta}) _effect(LedgerEntryDto entry) {
  if (entry.status != 'posted') return (ok: true, delta: 0);
  final units = entry.amountUnits?.asInt;
  if (units == null) return (ok: false, delta: 0);
  return (ok: true, delta: entry.type == 'debt' ? units : -units);
}

/// Rows in website order: ascending sequence, ties keep their place.
/// Null when a row has no sequence (the website would sort it as NaN).
List<LedgerEntryDto>? _bySequence(List<LedgerEntryDto> items) {
  if (items.any((entry) => entry.sequence == null)) return null;
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final bySequence = a.$2.sequence!.compareTo(b.$2.sequence!);
    return bySequence != 0 ? bySequence : a.$1.compareTo(b.$1);
  });
  return [for (final pair in indexed) pair.$2];
}

/// The website's `ve`: balance after each row, keyed by row id, starting
/// from [opening]. Null when the figures are not usable integers.
Map<String, int>? websiteRunningBalances({
  required MoneyValue? opening,
  required List<LedgerEntryDto> items,
}) {
  var running = opening?.asInt;
  if (running == null) return null;
  final ordered = _bySequence(items);
  if (ordered == null) return null;
  final balances = <String, int>{};
  for (final entry in ordered) {
    final effect = _effect(entry);
    if (!effect.ok) return null;
    running = running! + effect.delta;
    balances[entry.id] = running;
  }
  return balances;
}

/// The balance after the last row of [items], or [opening] when empty.
int? websiteClosingBalance({
  required MoneyValue? opening,
  required List<LedgerEntryDto> items,
}) {
  var running = opening?.asInt;
  if (running == null) return null;
  for (final entry in items) {
    final effect = _effect(entry);
    if (!effect.ok) return null;
    running = running! + effect.delta;
  }
  return running;
}

/// The balance before [entry]: its running value minus its own effect.
int? websiteBalanceBefore(LedgerEntryDto entry, int after) {
  final effect = _effect(entry);
  return effect.ok ? after - effect.delta : null;
}

/// The column is shown only when the balance after the last row equals the
/// server's stored balance for the card; otherwise nothing is shown.
/// [opening] is the oldest loaded page's `pageOpeningBalanceUnits` and
/// [items] every loaded row, as the website merges them.
Map<String, int>? websiteBalancesMatchingServer({
  required MoneyValue? opening,
  required List<LedgerEntryDto> items,
  required MoneyValue? serverBalance,
}) {
  final server = serverBalance?.asInt;
  if (server == null) return null;
  final balances = websiteRunningBalances(opening: opening, items: items);
  if (balances == null) return null;
  final closing = websiteClosingBalance(opening: opening, items: items);
  return closing == server ? balances : null;
}
