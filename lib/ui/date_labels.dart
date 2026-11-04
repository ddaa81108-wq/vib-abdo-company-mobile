/// Day and date for the top status strip (Ali, 2026-11-01).
///
/// Libya is UTC+2 all year (no DST), so Tripoli time is UTC + 2h whatever the
/// phone's own zone is. Arabic names, Latin digits like the rest of the app.
library;

const tripoliOffset = Duration(hours: 2);

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Wall-clock fields in Tripoli. The result is a UTC DateTime whose fields
/// read as Tripoli local time.
DateTime tripoliNow([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(tripoliOffset);

/// «الأحد 1 نوفمبر 2026», with [short] «الأحد 1/11/2026», and with
/// [numeric] only «1/11/2026» (last resort for a very narrow strip).
String tripoliDateLabel(
  DateTime tripoli, {
  bool short = false,
  bool numeric = false,
}) {
  final digits = '${tripoli.day}/${tripoli.month}/${tripoli.year}';
  if (numeric) return digits;
  final day = _weekdays[tripoli.weekday - 1];
  if (short) return '$day $digits';
  return '$day ${tripoli.day} ${_months[tripoli.month - 1]} ${tripoli.year}';
}

/// Time left until the next Tripoli midnight, plus one second of margin.
Duration untilTripoliMidnight([DateTime? now]) {
  final t = tripoliNow(now);
  final next = DateTime.utc(t.year, t.month, t.day + 1);
  return next.difference(t) + const Duration(seconds: 1);
}
