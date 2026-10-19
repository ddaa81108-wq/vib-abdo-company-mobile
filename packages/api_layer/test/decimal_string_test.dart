import 'package:flutter_api_layer/core/money/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const f = MoneyFormatter();
  test('rates stay text; formatter groups the string only', () {
    expect(DecimalString.tryParse('9.5')!.toJson(), '9.5');
    expect(DecimalString.tryParse('٩٫٥')!.value, '9.5');
    expect(DecimalString.tryParse('12500.250')!.value,
        '12500.250'); // trailing zero kept as typed
    expect(DecimalString.tryParse('1e3'), isNull);
    expect(DecimalString.tryParse('abc'), isNull);
    expect(f.formatDecimal(DecimalString.tryParse('12500.25')!), '12,500.25');
    expect(f.formatDecimalOrDash(null), '—');
    expect(DecimalString.fromJson('0.105263')!.value, '0.105263');
    expect(DecimalString.fromJson(null), isNull);
  });
}
