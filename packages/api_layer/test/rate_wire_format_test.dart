import 'dart:convert';

import 'package:flutter_api_layer/core/config/api_config.dart';
import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/core/network/idempotency.dart';
import 'package:flutter_api_layer/core/network/precise_json.dart';
import 'package:flutter_api_layer/core/network/wire_json.dart';
import 'package:flutter_api_layer/data/fake/fake_api_client.dart';
import 'package:flutter_api_layer/data/models/account_models.dart';
import 'package:flutter_api_layer/data/models/common.dart';
import 'package:flutter_api_layer/data/repositories/accounts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rate = DecimalString.tryParse('9.5')!;
  final precise =
      DecimalString.tryParse('0.1000000000000000055511151231257827')!;

  test(
      'number mode writes the literal digits (no float), string mode quotes them',
      () {
    final body = {
      'requestId': 'r1',
      'factor': rate,
      'precise': precise,
      'amountUnits': 1500,
      'note': 'x"y'
    };
    expect(WireJson.encode(body, RateWireFormat.number),
        '{"requestId":"r1","factor":9.5,"precise":0.1000000000000000055511151231257827,"amountUnits":1500,"note":"x\\"y"}');
    expect(WireJson.encode(body, RateWireFormat.string),
        '{"requestId":"r1","factor":"9.5","precise":"0.1000000000000000055511151231257827","amountUnits":1500,"note":"x\\"y"}');
    // Both outputs are valid JSON.
    expect(
        jsonDecode(WireJson.encode(body, RateWireFormat.number)), isA<Map>());
    expect(jsonDecode(WireJson.encode(body, RateWireFormat.string))['factor'],
        '9.5');
  });

  test('canonical text is a valid JSON number literal', () {
    expect(DecimalString.tryParse('007.50')!.value, '7.50');
    expect(DecimalString.tryParse('-00')!.value, '-0');
    expect(
        jsonDecode(WireJson.encode(
            [DecimalString.tryParse('007.50')], RateWireFormat.number)),
        isA<List>());
  });

  test(
      'default ApiConfig wire format is number (what the server accepts today)',
      () {
    expect(const ApiConfig(baseUrl: 'https://x.invalid').rateWireFormat,
        RateWireFormat.number);
  });

  for (final mode in RateWireFormat.values) {
    test('repository bodies use the configured mode: $mode', () async {
      final fake = FakeApiClient(latency: Duration.zero, rateWireFormat: mode);
      await fake.post('/api/auth/login',
          body: {'username': 'admin', 'password': 'x'});
      final repo = RemoteAccountsRepository(fake);
      await repo.updateExchangeRate(rate, MutationMeta(expectedVersion: 2));
      expect(
          fake.lastWireBody,
          contains(mode == RateWireFormat.number
              ? '"egpPerLyd":9.5'
              : '"egpPerLyd":"9.5"'));

      await repo.addTransaction(
        AccountSection.customers,
        'c_55',
        AccountTransactionRequest.debt(
            inputValue: 500,
            mode: CalculationMode.divide,
            factor: rate,
            date: DateTime(2026, 10, 19)),
        MutationMeta(expectedVersion: 4),
      );
      expect(
          fake.lastWireBody,
          contains(mode == RateWireFormat.number
              ? '"factor":9.5'
              : '"factor":"9.5"'));
    });
  }

  test('incoming rates keep their exact body text (PreciseJson), doubles rejected', () {
    final d = PreciseJson.decode('{"r":9.50}') as Map;
    expect(DecimalString.fromJson(d['r'])!.value, '9.50');
    expect(DecimalString.fromJson('9.50')!.value, '9.50');
    expect(() => DecimalString.fromJson(9.5),
        throwsA(isA<InvalidServerResponseException>()));
  });
}
