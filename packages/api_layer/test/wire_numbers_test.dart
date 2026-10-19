import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_api_layer/core/config/api_config.dart';
import 'package:flutter_api_layer/core/money/decimal_string.dart';
import 'package:flutter_api_layer/core/network/api_exception.dart';
import 'package:flutter_api_layer/core/network/dio_api_client.dart';
import 'package:flutter_api_layer/core/network/wire_json.dart';
import 'package:flutter_api_layer/data/models/common.dart';
import 'package:flutter_api_layer/data/models/treasury_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rates keep the original numeric token and reject bad text', () {
    final parsed = decodeWireJson(
      '{"exchangeRate":48.750000,"units":125000,"bad":125000.0}',
    ) as Map;
    expect(parsed['units'], 125000);
    expect(parsed['units'], isA<int>());
    expect((parsed['exchangeRate'] as JsonNumber).literal, '48.750000');
    expect(DecimalString.fromJson(parsed['exchangeRate'])!.value, '48.750000');
    expect(
      () => unitsOrNull(parsed['bad']),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(
      () => unitsOrNull('125000'),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(
      () => unitsOrNull(125000.0),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(unitsOrNull(125000), 125000);
    expect(unitsOrNull(null), isNull);

    final tiny = decodeWireJson('{"r":1e-7}') as Map;
    expect((tiny['r'] as JsonNumber).literal, '1e-7');
    expect(
      () => DecimalString.fromJson(tiny['r']),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(
      () => DecimalString.fromJson(1e-7),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(
      () => DecimalString.fromJson('1,000'),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(
      () => DecimalString.fromJson('1e-7'),
      throwsA(isA<InvalidServerResponseException>()),
    );
    expect(
      () => TreasurySummaryDto.fromData({
        'totals': {'activeCashUnits': '125000'},
      }),
      throwsA(isA<InvalidServerResponseException>()),
    );
    final neutral = TreasurySummaryDto.fromData({
      'totals': {'activeCashUnits': -5},
    });
    expect(neutral.activeCashTone, isNull);
    expect(neutral.activeCashUnits, -5);
  });

  test('dio plain responses keep rate digits', () async {
    final dio = Dio(
      DioApiClient.baseOptions(
        const ApiConfig(baseUrl: 'https://local.invalid'),
      ),
    )..httpClientAdapter = _Adapter(
        ResponseBody.fromString(
          '{"ok":true,"data":{"exchangeRate":48.750000,"amountUnits":125000}}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
    final res = await DioApiClient(dio).get('/api/x');
    expect(
      DecimalString.fromJson(res.dataMap['exchangeRate'])!.value,
      '48.750000',
    );
    expect(res.dataMap['amountUnits'], 125000);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final ResponseBody body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => body;

  @override
  void close({bool force = false}) {}
}
