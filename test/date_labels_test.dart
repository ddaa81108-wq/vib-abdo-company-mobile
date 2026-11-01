import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/ui/date_labels.dart';

void main() {
  test('Tripoli day and date, full and short, Latin digits', () {
    final t = tripoliNow(DateTime.utc(2026, 11, 1, 3, 0));
    expect(tripoliDateLabel(t), 'الأحد 1 نوفمبر 2026');
    expect(tripoliDateLabel(t, short: true), 'الأحد 1/11/2026');
    expect(tripoliDateLabel(t), isNot(matches(RegExp('[٠-٩]'))));
  });

  test('the date follows Tripoli (UTC+2), not the device zone', () {
    // 22:30 UTC on 31 Oct is 00:30 on 1 Nov in Tripoli.
    final t = tripoliNow(DateTime.utc(2026, 10, 31, 22, 30));
    expect(tripoliDateLabel(t), 'الأحد 1 نوفمبر 2026');
    final before = tripoliNow(DateTime.utc(2026, 10, 31, 21, 59));
    expect(tripoliDateLabel(before), 'السبت 31 أكتوبر 2026');
  });

  test('the strip timer fires just after the next Tripoli midnight', () {
    // 23:59:30 Tripoli -> 30s to midnight, plus 1s margin.
    final wait = untilTripoliMidnight(DateTime.utc(2026, 11, 1, 21, 59, 30));
    expect(wait, const Duration(seconds: 31));
    // Month and year roll over.
    final year = untilTripoliMidnight(DateTime.utc(2026, 12, 31, 21, 0));
    expect(year, const Duration(hours: 1, seconds: 1));
  });
}
