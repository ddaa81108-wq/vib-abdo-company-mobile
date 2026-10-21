import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default defines stay on the fake client and keep no host', () {
    final config = ApiConfig.fromEnvironment();
    expect(config.useFakeApi, isTrue);
    expect(config.baseUrl, isEmpty);
    final layer = ApiLayer.create(config: config);
    addTearDown(layer.dispose);
    expect(layer.useFakeApi, isTrue);
  });

  test('fake mode does not require or keep API_BASE', () {
    final config = ApiConfig.fromDefines(
      useFakeApi: true,
      apiBase: 'https://user:secret@staging.example',
    );
    expect(config.useFakeApi, isTrue);
    expect(config.baseUrl, isEmpty);
  });

  test('real mode fails clearly when API_BASE is missing', () {
    expect(
      () => ApiConfig.fromDefines(useFakeApi: false, apiBase: '   '),
      throwsA(
        isA<ApiConfigException>().having(
          (error) => error.message,
          'message',
          allOf(contains('API_BASE'), contains('USE_FAKE_API=false')),
        ),
      ),
    );
  });

  test('real mode rejects credentials, paths, and queries without echoing them',
      () {
    const secret = 's3cret-value';
    for (final raw in [
      'https://user:$secret@staging.example',
      'https://staging.example/api',
      'https://staging.example?token=$secret',
      'https://staging.example#frag',
      'ftp://staging.example',
      'staging.example',
    ]) {
      expect(
        () => ApiConfig.fromDefines(useFakeApi: false, apiBase: raw),
        throwsA(
          isA<ApiConfigException>().having(
            (error) => error.toString(),
            'text',
            isNot(contains(secret)),
          ),
        ),
        reason: raw.split(secret).first,
      );
    }
  });

  test('a staging origin is normalized and does not open a socket by itself',
      () {
    final config = ApiConfig.fromDefines(
      useFakeApi: false,
      apiBase: 'https://staging.example.com/',
    );
    expect(config.baseUrl, 'https://staging.example.com');
    expect(
      ApiConfig.requireRealBaseUrl('https://staging.example.com:8443'),
      'https://staging.example.com:8443',
    );
    final layer = ApiLayer.create(
      config: config,
      cookieStore: InMemoryCookieStore(),
    );
    addTearDown(layer.dispose);
    expect(layer.useFakeApi, isFalse);
  });

  test('building the real stack without an origin throws before Dio is used',
      () {
    expect(
      () => ApiLayer.create(
        config: const ApiConfig(baseUrl: '', useFakeApi: false),
        cookieStore: InMemoryCookieStore(),
      ),
      throwsA(isA<ApiConfigException>()),
    );
  });
}
