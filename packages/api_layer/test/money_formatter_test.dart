import 'package:flutter_api_layer/core/money/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const f = MoneyFormatter();
  test('whole units, grouping, sign, per-currency symbol', () {
    expect(f.format(0, Currency.lyd), '0 د.ل');
    expect(f.format(320, Currency.lyd), '320 د.ل');
    expect(f.format(1250000, Currency.egp), '1,250,000 ج.م');
    expect(f.format(-125000, Currency.lyd), '-125,000 د.ل');
    expect(f.formatOrDash(null, Currency.lyd), '—');
  });
  test('scaled formatting is string-only', () {
    const f3 = MoneyFormatter(unitScale: 3);
    expect(f3.format(1250500, Currency.lyd), '1,250.500 د.ل');
    expect(f3.format(-5, Currency.lyd), '-0.005 د.ل');
    expect(f.formatScaled(9500000, 6), '9.5');
  });
  test('plain scaled text has no grouping and round-trips as a rate', () {
    expect(f.plainScaled(1500000, 6), '1.5');
    expect(f.plainScaled(2000000, 6), '2');
    expect(f.plainScaled(105263, 6), '0.105263');
    expect(f.plainScaled(12500250000, 6), '12500.25');
    expect(f.formatScaled(12500250000, 6), '12,500.25');
    expect(DecimalString.tryParse(f.plainScaled(105263, 6))?.value, '0.105263');
    expect(
      DecimalString.tryParse(f.formatScaled(12500250000, 6)),
      isNull,
    );
  });
}
