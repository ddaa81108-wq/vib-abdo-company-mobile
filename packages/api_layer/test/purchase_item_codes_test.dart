import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const allowed = PurchaseItemCodes.values;

  test('the contract list is vodafone_cash and custom, not the old names', () {
    expect(allowed, contains(PurchaseItemCodes.vodafoneCash));
    expect(allowed, contains(PurchaseItemCodes.custom));
    expect(allowed, isNot(contains('vodafone')));
    expect(allowed, isNot(contains('other')));
  });

  test('the fake client rejects an item code outside the contract list', () async {
    final api = FakeApiClient(latency: Duration.zero);
    await api.post('/api/auth/login', body: {
      'username': 'admin.demo',
      'password': 'demo-only',
    });

    Future<void> rejected(String code, [String? label]) {
      return expectLater(
        api.post('/api/purchases/al_bayan', body: {
          'requestId': 'r-$code',
          'expectedDayVersion': 1,
          'itemCode': code,
          if (label != null) 'itemLabel': label,
        }),
        throwsA(
          isA<BadRequestException>().having((e) => e.code, 'code', 'VALIDATION_ERROR'),
        ),
      );
    }

    await rejected('vodafone', 'فودافون');
    await rejected('other', PurchaseItemCodes.customCaption);
    await rejected('custom');
    await rejected('custom', '');
    await rejected('custom', PurchaseItemCodes.customCaption);
    await rejected('not-a-code');

    final typed = await api.post('/api/purchases/al_bayan', body: {
      'requestId': 'r-custom',
      'expectedDayVersion': 1,
      'itemCode': PurchaseItemCodes.custom,
      'itemLabel': 'صنف خاص',
    });
    expect(typed.dataMap['entryId'], 'pe_new');
    expect(api.lastWireBody, contains('صنف خاص'));
    expect(api.lastWireBody, isNot(contains(PurchaseItemCodes.customCaption)));

    final known = await api.post('/api/purchases/al_bayan', body: {
      'requestId': 'r-known',
      'expectedDayVersion': 1,
      'itemCode': PurchaseItemCodes.vodafoneCash,
    });
    expect(known.dataMap['entryId'], 'pe_new');
  });
}
