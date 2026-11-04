import 'package:flutter_api_layer/api_layer.dart';

/// Where a 05:00 difference came from.
enum FiveAmDiffSource {
  /// The server's own `netChangeUnits` (always preferred).
  server,

  /// Display only (Ali approved, 2026-11-04): this recorded snapshot's net
  /// minus the previous recorded snapshot's net. Never sent or stored.
  display,
}

class FiveAmDiff {
  const FiveAmDiff(this.units, this.source);

  final int units;
  final FiveAmDiffSource source;

  @override
  bool operator ==(Object other) =>
      other is FiveAmDiff && other.units == units && other.source == source;

  @override
  int get hashCode => Object.hash(units, source);

  @override
  String toString() => 'FiveAmDiff($units, ${source.name})';
}

/// The recorded 05:00 net of [row] in integer units, or null when the
/// snapshot is pending, missing, or not a valid integer.
int? recordedFiveAmNet(DailyReportRowDto row) {
  final snap = row.fiveAmClosing;
  if (snap == null) return null;
  if (snap.state != null &&
      snap.state != FiveAmClosingState.recorded &&
      snap.state != FiveAmClosingState.unknown) {
    return null;
  }
  final net = snap.netUnits;
  if (net == null || net.invalid) return null;
  return net.units;
}

/// الفرق per row, keyed by [DailyReportRowDto.sequence].
///
/// Rows are taken in business-day order (oldest first). A recorded snapshot
/// is compared with the previous *recorded* snapshot in [rows]; missing or
/// pending days are skipped, never created. The oldest recorded snapshot
/// and every pending row get null ('–'). A server `netChangeUnits` wins.
/// Integer math only.
Map<int, FiveAmDiff?> fiveAmDiffs(List<DailyReportRowDto> rows) {
  final ordered = [...rows]
    ..sort((a, b) {
      final da = a.date ?? '';
      final db = b.date ?? '';
      final byDate = da.compareTo(db);
      return byDate != 0 ? byDate : a.sequence.compareTo(b.sequence);
    });
  final out = <int, FiveAmDiff?>{};
  int? previous;
  for (final row in ordered) {
    final net = recordedFiveAmNet(row);
    final server = row.netChangeUnits;
    if (net == null) {
      out[row.sequence] = null;
      continue;
    }
    if (server != null && !server.invalid && server.units != null) {
      out[row.sequence] = FiveAmDiff(server.units!, FiveAmDiffSource.server);
    } else {
      out[row.sequence] = previous == null
          ? null
          : FiveAmDiff(net - previous, FiveAmDiffSource.display);
    }
    previous = net;
  }
  return out;
}
