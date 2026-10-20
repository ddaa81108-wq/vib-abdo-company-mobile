import 'package:flutter_api_layer/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromEnvironment defaults to the fake client and the placeholder origin',
      () {
    // tool/check.sh and `flutter test` pass no --dart-define, so this locks
    // the compile-time defaults. Do not point this run at a define file.
    final config = ApiConfig.fromEnvironment();
    expect(config.useFakeApi, isTrue);
    expect(config.baseUrl, 'https://staging.example.invalid');
    expect(config.enableDebugLogging, isFalse);
    expect(config.authStrategy, AuthStrategyKind.cookieCsrf);
    expect(config.moneyUnitScale, 0);
    expect(config.rateWireFormat, RateWireFormat.number);
    expect(config.pollingInterval, const Duration(seconds: 4));
    expect(config.connectTimeout, const Duration(seconds: 15));
    expect(config.receiveTimeout, const Duration(seconds: 30));
  });
}
