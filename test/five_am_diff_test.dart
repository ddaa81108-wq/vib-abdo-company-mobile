import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/reports/five_am_diff.dart';

DailyReportRowDto row(
  int seq,
  String date, {
  int? net,
  String state = 'recorded',
  int? change,
}) => DailyReportRowDto.fromJson({
  'sequence': seq,
  'businessDate': date,
  'netUnits': 0,
  'netChangeUnits': ?change,
  'fiveAmClosing': {'state': state, 'netUnits': net},
});

const d = FiveAmDiffSource.display;

void main() {
  test('consecutive recorded snapshots, newest-first input', () {
    final out = fiveAmDiffs([
      row(3, '2026-11-03', net: 209650),
      row(2, '2026-11-02', net: 443475),
      row(1, '2026-11-01', net: 428387),
    ]);
    expect(out[1], isNull); // oldest: '–'
    expect(out[2], const FiveAmDiff(15088, d));
    expect(out[3], const FiveAmDiff(-233825, d));
  });

  test('gaps compare with the previous recorded snapshot, no days created', () {
    final out = fiveAmDiffs([
      row(5, '2026-11-05', net: 100),
      row(2, '2026-11-01', net: 40),
    ]);
    expect(out[5], const FiveAmDiff(60, d));
    expect(out.length, 2);
  });

  test('pending rows show – and are skipped as a previous', () {
    final out = fiveAmDiffs([
      row(4, '2026-11-04', net: null, state: 'pending'),
      row(3, '2026-11-03', net: 50),
      row(2, '2026-11-02', net: 0, state: 'pending'),
      row(1, '2026-11-01', net: 20),
    ]);
    expect(out[4], isNull);
    expect(out[2], isNull);
    expect(out[3], const FiveAmDiff(30, d));
  });

  test('single row and zero difference', () {
    expect(fiveAmDiffs([row(1, '2026-11-01', net: 7)])[1], isNull);
    final same = fiveAmDiffs([
      row(2, '2026-11-02', net: 13264),
      row(1, '2026-11-01', net: 13264),
    ]);
    expect(same[2], const FiveAmDiff(0, d));
  });

  test('negative nets use integer math', () {
    final out = fiveAmDiffs([
      row(2, '2026-11-02', net: -5),
      row(1, '2026-11-01', net: 9007199254740000),
    ]);
    expect(out[2]!.units, -5 - 9007199254740000);
  });

  test('a server netChangeUnits wins, also for the oldest row', () {
    final out = fiveAmDiffs([
      row(2, '2026-11-02', net: 100, change: 999),
      row(1, '2026-11-01', net: 40, change: -3),
    ]);
    expect(out[2], const FiveAmDiff(999, FiveAmDiffSource.server));
    expect(out[1], const FiveAmDiff(-3, FiveAmDiffSource.server));
  });
}
