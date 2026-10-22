import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_api_layer/core/config/api_config.dart';
import 'package:flutter_api_layer/core/config/release_fake_api_guard.dart';
import 'package:flutter_api_layer/core/network/fake_client_builder_release.dart'
    as release_builder;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromEnvironment keeps the fake default and rejects a missing origin',
      () {
    // Fake mode (the default, and what CI passes) stores no host.
    // Real mode requires an explicit http(s) origin. There is no placeholder.
    const useFake = bool.fromEnvironment('USE_FAKE_API', defaultValue: true);
    const apiBase = String.fromEnvironment('API_BASE');
    if (useFake) {
      final config = ApiConfig.fromEnvironment();
      expect(config.useFakeApi, isTrue);
      expect(config.baseUrl, isEmpty);
      expect(config.useFakeApi, kUseFakeApiFromEnvironment);
    } else if (apiBase.isEmpty) {
      expect(ApiConfig.fromEnvironment, throwsA(isA<ApiConfigException>()));
      expect(kUseFakeApiFromEnvironment, isFalse);
    } else {
      final config = ApiConfig.fromEnvironment();
      expect(config.useFakeApi, isFalse);
      expect(config.baseUrl, isNotEmpty);
      expect(config.baseUrl, isNot(contains('example.invalid')));
    }
    final defaults = ApiConfig.fromDefines(useFakeApi: true, apiBase: '');
    expect(defaults.enableDebugLogging, isFalse);
    expect(defaults.authStrategy, AuthStrategyKind.cookieCsrf);
    expect(defaults.moneyUnitScale, 0);
    expect(defaults.rateWireFormat, RateWireFormat.number);
    expect(releaseFakeApiGuard, isA<ReleaseFakeApiGuard>());
    if (kReleaseMode) {
      expect(kUseFakeApiFromEnvironment, isFalse);
    }

    expect(
      () => ApiConfig.fromDefines(useFakeApi: false, apiBase: ''),
      throwsA(isA<ApiConfigException>()),
    );
    expect(
      () => ApiConfig.fromDefines(useFakeApi: false, apiBase: '/relative'),
      throwsA(isA<ApiConfigException>()),
    );
    expect(
      () => ApiConfig.fromDefines(
        useFakeApi: false,
        apiBase: 'ftp://staging.example.com',
      ),
      throwsA(isA<ApiConfigException>()),
    );
    expect(
      () => ApiConfig.fromDefines(
        useFakeApi: false,
        apiBase: 'https://user:secret@staging.example.com',
      ),
      throwsA(
        isA<ApiConfigException>().having(
          (error) => error.toString(),
          'text',
          isNot(contains('secret')),
        ),
      ),
    );
    expect(
      () => ApiConfig.fromDefines(
        useFakeApi: false,
        apiBase: 'https://staging.example.com/api',
      ),
      throwsA(isA<ApiConfigException>()),
    );
    expect(
      () => ApiConfig.fromDefines(
        useFakeApi: false,
        apiBase: 'https://staging.example.com?q=1',
      ),
      throwsA(isA<ApiConfigException>()),
    );
    expect(
      () => ApiConfig.fromDefines(
        useFakeApi: false,
        apiBase: 'https://staging.example.com#frag',
      ),
      throwsA(isA<ApiConfigException>()),
    );
    expect(
      ApiConfig.fromDefines(
        useFakeApi: false,
        apiBase: 'https://staging.example.com/',
      ).baseUrl,
      'https://staging.example.com',
    );
    final fake = ApiConfig.fromDefines(
      useFakeApi: true,
      apiBase: 'https://staging.example.invalid',
    );
    expect(fake.useFakeApi, isTrue);
    expect(fake.baseUrl, isEmpty);
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
        config: const ApiConfig(baseUrl: ''),
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
    expect(releaseSource.contains('fake_large_catalog'), isFalse);
    expect(releaseSource.contains('FakeLargeCatalog'), isFalse);
    expect(releaseSource.contains('FAKE_DATASET'), isFalse);
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
      final mentionsFake = text.contains('fake_api_client.dart') ||
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

    final factory =
        File('lib/core/network/api_client_factory.dart').readAsStringSync();
    expect(factory.contains('fake_api_client.dart'), isFalse);
    expect(
      factory.contains(
        "if (dart.vm.product) 'fake_client_builder_release.dart'",
      ),
      isTrue,
    );
  });
}
