import 'package:flutter_api_layer/api_layer.dart';

/// Explicit synthetic server responses for CI. Local QA can replay actual
/// read-only server query outputs through SEARCH_PARITY_FIXTURE instead.
List<Map<String, dynamic>> syntheticSearchRecordings() {
  final cases = <String, List<int>>{
    'تجربة': List.generate(42, (i) => i),
    'جرب': List.generate(42, (i) => i),
    'حساب تجربة 17': [17],
    '0017': [17],
    'تجربة غير مطابق': [],
    'اسم غير موجود': [],
  };
  return [
    for (final entry in cases.entries)
      {
        'query': entry.key,
        'responses': {
          for (final section in AccountSection.values)
            section.path: [
              for (
                var offset = 0;
                offset < (entry.value.isEmpty ? 1 : entry.value.length);
                offset += 30
              )
                {
                  'cursor': offset == 0 ? null : 'page-$offset',
                  'data': {
                    'summary': <String, dynamic>{},
                    'nextCursor': offset + 30 < entry.value.length
                        ? 'page-${offset + 30}'
                        : null,
                    'items': [
                      for (final i in entry.value.skip(offset).take(30))
                        {
                          'id': 'same-id-$i',
                          'name': 'حساب تجربة $i',
                          'phone': '092000${i.toString().padLeft(4, '0')}',
                          'balanceUnits': i.isEven ? 987654321 : -123456789,
                          'currency': section.currency.code,
                        },
                    ],
                  },
                },
            ],
        },
      },
  ];
}
