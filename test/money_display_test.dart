import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/models/models.dart';

void main() {
  test(
    'a server integer is shown with its own currency and nothing is combined',
    () {
      const formatter = MoneyFormatter();
      expect(formatter.format(320, Currency.lyd), '320 د.ل');
      expect(formatter.format(15000, Currency.egp), '15,000 ج.م');
      expect(formatter.format(-125000, Currency.lyd), '-125,000 د.ل');
      expect(formatter.formatOrDash(null, Currency.egp), '—');
    },
  );
}
