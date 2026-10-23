import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/features/collections/egyptian_link_pause.dart';

void main() {
  test('egyptian deposit section keys are paused', () {
    expect(isEgyptianDepositSection('egyptian_deposits'), isTrue);
    expect(isEgyptianDepositSection('egyptian-deposits'), isTrue);
    expect(isEgyptianDepositSection('customer_debts'), isFalse);
    expect(isEgyptianDepositSection('companies'), isFalse);
    expect(isEgyptianDepositSection('libyan_deposits'), isFalse);
    expect(isEgyptianDepositSection('libyan-deposits'), isFalse);
    expect(isEgyptianDepositSection(null), isFalse);
  });

  test('the picker drops an Egyptian card and keeps LYD cards', () {
    final items = <Json>[
      {'id': 'c_55', 'name': 'عميل', 'sectionKey': 'customer_debts'},
      {'id': 'co_1', 'name': 'شركة', 'sectionKey': 'company_debts'},
      {'id': 'ld_1', 'name': 'ليبي', 'sectionKey': 'libyan_deposits'},
      {'id': 'eg_1', 'name': 'مصري', 'sectionKey': 'egyptian_deposits'},
      {'id': 'plain', 'name': 'بلا قسم'},
    ];
    final offered = linkableCandidates(items);
    expect(offered.map((item) => item['id']), [
      'c_55',
      'co_1',
      'ld_1',
      'plain',
    ]);
    final seen = <String, Json>{};
    rememberLinkCandidates(seen, items);
    expect(isPausedEgyptianLink(seen['eg_1']), isTrue);
    expect(isPausedEgyptianLink(seen['c_55']), isFalse);
    expect(isPausedEgyptianLink(seen['plain']), isFalse);
    expect(isPausedEgyptianLink(null), isFalse);
    rememberLinkCandidates(seen, [
      {'id': 'eg_1', 'name': 'مصري'},
    ]);
    expect(isPausedEgyptianLink(seen['eg_1']), isTrue);
  });
}
