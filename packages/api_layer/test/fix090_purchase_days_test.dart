import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entryDays supplies the day status a tagged reload omits', () {
    final page = PurchasesPage.fromData({
      'day': {
        'id': 'day-open',
        'status': 'draft',
        'version': 4,
        'correctionOpen': false,
      },
      'entryDays': {
        'day-open': {
          'dayStatus': 'draft',
          'dayVersion': 4,
          'dayClosingDebtUnits': 80,
          'correctionOpen': false,
        },
        'day-old': {
          'dayStatus': 'finalized',
          'dayVersion': 2,
          'correctionOpen': false,
        },
      },
      'entries': [
        {
          'id': 'a',
          'dayId': 'day-open',
          'sequence': 1,
          'version': 1,
          'egpValueUnits': 100,
          'paidUnits': 10,
          'resultUnits': 10,
        },
        {
          'id': 'b',
          'dayId': 'day-open',
          'sequence': 2,
          'version': 1,
          'dayStatus': 'finalized',
        },
        {
          'id': 'c',
          'dayId': 'day-old',
          'sequence': 1,
          'version': 1,
        },
      ],
    });

    final open = page.entries.where((entry) => entry.dayId == 'day-open');
    expect(open.map((entry) => entry.dayStatus), ['draft', 'draft']);
    expect(open.every((entry) => entry.dayVersion == 4), isTrue);
    final posted = page.entries.singleWhere((entry) => entry.id == 'c');
    expect(posted.dayStatus, 'finalized');
    expect(posted.dayVersion, 2);
  });
}
