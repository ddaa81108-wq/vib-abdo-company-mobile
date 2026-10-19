import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/models/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home, cash status, version, and rates stay server text', () {
    final home = HomeDto.fromData({
      'businessDate': '2026-10-19',
      'summaries': [
        {
          'key': 'customers.netBalance',
          'section': 'customers',
          'title': 'صافي ديون العملاء',
          'valueUnits': 320,
          'currency': 'LYD',
        },
      ],
      'counters': {'collections': 1},
      'oldDebts': [
        {
          'id': 'c_55',
          'section': 'customers',
          'name': 'عميل تجريبي',
          'balanceUnits': 320,
          'currency': 'LYD',
          'ageStatusLabel': 'منذ 4 أيام',
        },
      ],
    });
    expect(home.businessDate, '2026-10-19');
    expect(home.summaries.single.valueUnits, 320);
    expect(home.counters['collections'], 1);
    expect(home.oldDebts?.single.ageStatusLabel, 'منذ 4 أيام');

    final submission = CollectionSubmissionDto.fromJson({
      'id': 'sb_2',
      'mode': 'full',
      'amountUnits': 250,
      'status': 'approved',
      'version': 3,
      'cashStatus': 'pending',
    });
    expect(submission.cashStatus, CashStatus.pending);
    expect(submission.version, 3);
    expect(submission.amountUnits, 250);

    final rate = ExchangeRateDto.fromData({'egpPerLyd': '9.5', 'version': 2});
    expect(rate.egpPerLyd?.value, '9.5');
    expect(rate.version, 2);
    expect(const MoneyFormatter().formatDecimal(rate.egpPerLyd!), '9.5');
    expect(const MoneyFormatter().format(320, Currency.lyd), '320 د.ل');
  });
}
