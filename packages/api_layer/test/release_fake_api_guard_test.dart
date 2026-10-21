import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/core/config/api_config.dart';
import 'package:flutter_api_layer/core/config/release_fake_api_guard.dart';
import 'package:flutter_api_layer/core/network/fake_client_builder_release.dart'
    as release_builder;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromEnvironment keeps the fake default outside release', () {
    final config = ApiConfig.fromEnvironment();
    expect(config.useFakeApi, kUseFakeApiFromEnvironment);
    expect(config.baseUrl, 'https://staging.example.invalid');
    expect(config.enableDebugLogging, isFalse);
    expect(config.authStrategy, AuthStrategyKind.cookieCsrf);
    expect(config.moneyUnitScale, 0);
    expect(config.rateWireFormat, RateWireFormat.number);
    expect(releaseFakeApiGuard, isA<ReleaseFakeApiGuard>());
    if (kReleaseMode) {
      expect(kUseFakeApiFromEnvironment, isFalse);
    }
  });

  test('release mode rejects a fake client at runtime', () {
    expect(
      () => rejectFakeApiInRelease(true, releaseMode: true),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          releaseFakeApiRejectedMessage,
        ),
      ),
    );
    expect(
      () => rejectFakeApiInRelease(false, releaseMode: true),
      returnsNormally,
    );
    expect(
      () => rejectFakeApiInRelease(true, releaseMode: false),
      returnsNormally,
    );
  });

  test('release builder throws and does not name demo profiles', () {
    expect(
      () => release_builder.buildFakeStack(
        config: const ApiConfig(baseUrl: 'https://staging.example.invalid'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          releaseFakeApiRejectedMessage,
        ),
      ),
    );

    final releaseSource = File(
      'lib/core/network/fake_client_builder_release.dart',
    ).readAsStringSync();
    expect(releaseSource.contains('FakeApiClient'), isFalse);
    expect(releaseSource.contains('fake_fixtures'), isFalse);
    expect(releaseSource.contains('example.invalid'), isFalse);
    expect(releaseSource.contains('demo-only'), isFalse);
  });

  test('only the debug builder imports the fake client', () {
    const allowed = 'lib/core/network/fake_client_builder.dart';
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      final mentionsFake =
          text.contains('fake_api_client.dart') ||
          text.contains('fake_fixtures.dart');
      if (!mentionsFake) continue;
      final normalized = file.path.replaceAll('\\', '/');
      final isFakeLibrary =
          normalized.endsWith('lib/data/fake/fake_api_client.dart') ||
          normalized.endsWith('lib/data/fake/fake_fixtures.dart');
      if (isFakeLibrary || normalized.endsWith(allowed)) continue;
      offenders.add(normalized);
    }
    expect(offenders, isEmpty);

    final factory = File('lib/core/network/api_client_factory.dart')
        .readAsStringSync();
    expect(factory.contains('fake_api_client.dart'), isFalse);
    expect(
      factory.contains(
        "if (dart.vm.product) 'fake_client_builder_release.dart'",
      ),
      isTrue,
    );
  });
}
