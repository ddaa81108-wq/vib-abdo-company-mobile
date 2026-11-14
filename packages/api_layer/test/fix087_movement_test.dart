import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list cards use updatedAt then createdAt for آخر حركة', () {
    const sections = AccountSection.values;
    for (final section in sections) {
      final card = AccountCardDto.fromJson({
        'id': 'shape',
        'name': 'كرت',
        'balanceUnits': 10,
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-22T22:33:25.561Z',
      }, section);
      expect(
        card.lastActivityAt,
        DateTime.utc(2026, 10, 22, 22, 33, 25, 561),
        reason: section.path,
      );
    }

    final dedicated = AccountCardDto.fromJson({
      'id': 'dedicated',
      'name': 'كرت',
      'balanceUnits': 1,
      'lastActivityAt': '2026-11-02T08:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    }, AccountSection.customers);
    expect(dedicated.lastActivityAt, DateTime.utc(2026, 11, 2, 8));

    final createdOnly = AccountCardDto.fromJson({
      'id': 'created',
      'name': 'كرت',
      'balanceUnits': 1,
      'createdAt': '2026-09-03T05:00:00.000Z',
    }, AccountSection.companies);
    expect(createdOnly.lastActivityAt, DateTime.utc(2026, 9, 3, 5));

    // Egyptian system cards in the observed list use a space, not `T`.
    final spaced = AccountCardDto.fromJson({
      'id': 'system-egp-vodafone:org-default',
      'name': 'فودافون',
      'balanceUnits': 4900,
      'createdAt': '2026-10-22 22:33:23',
      'updatedAt': '2026-10-22T22:33:25.399Z',
    }, AccountSection.egyptianDeposits);
    expect(spaced.lastActivityAt, DateTime.utc(2026, 10, 22, 22, 33, 25, 399));

    final none = AccountCardDto.fromJson({
      'id': 'empty',
      'name': 'بدون وقت',
      'balanceUnits': 0,
    }, AccountSection.libyanDeposits);
    expect(none.lastActivityAt, isNull);
  });
}
