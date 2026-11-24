import 'package:flutter_api_layer/data/models/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextBefore alone exposes older rows without inventing totals', () {
    final page = Paged.fromData({
      'items': [
        {'id': 'cash-1', 'amountUnits': 17}
      ],
      'nextBefore': '9',
    }, (row) => row);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, '9');
    expect(page.items.single['amountUnits'], 17);
  });

  test('both cursor styles stop on null or empty and honor explicit hasMore',
      () {
    for (final key in ['nextBefore', 'nextCursor']) {
      for (final end in [null, '']) {
        expect(Paged.fromData({'items': [], key: end}, (row) => row).hasMore,
            isFalse);
      }
      final next = Paged.fromData({'items': [], key: '2'}, (row) => row);
      expect(next.hasMore, isTrue);
      expect(next.nextCursor, '2');
    }
    expect(Paged.fromData({'items': [], 'hasMore': true}, (row) => row).hasMore,
        isTrue);
    expect(Paged.fromData({'items': []}, (row) => row).hasMore, isFalse);
  });
}
