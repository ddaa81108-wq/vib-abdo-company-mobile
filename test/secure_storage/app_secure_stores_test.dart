import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/secure_storage/app_secure_stores.dart';

void main() {
  test('token writes stay in the injected store and can be cleared', () async {
    final tokens = InMemoryTokenStorage();
    final cookies = InMemoryCookieStore();
    final stores = AppSecureStores(cookies: cookies, tokens: tokens);

    expect(identical(stores.tokens, tokens), isTrue);
    expect(identical(stores.cookies, cookies), isTrue);

    await stores.tokens.saveTokens(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
      expiresInSeconds: 60,
    );
    expect(await tokens.readAccessToken(), 'fake-access');
    expect(await tokens.readRefreshToken(), 'fake-refresh');
    expect(await tokens.readAccessExpiry(), isNotNull);

    await stores.cookies.saveFromSetCookie(['session=fake-session']);
    expect(await cookies.cookieHeader(), 'session=fake-session');

    await stores.tokens.clear();
    await stores.cookies.clear();
    expect(await tokens.readAccessToken(), isNull);
    expect(await cookies.isEmpty(), isTrue);
  });

  test(
    'fake mode accepts the stores and does not require them to sign in',
    () async {
      final stores = AppSecureStores(
        cookies: InMemoryCookieStore(),
        tokens: InMemoryTokenStorage(),
      );
      final layer = ApiLayer.create(
        config: const ApiConfig(
          baseUrl: 'https://fake.invalid',
          useFakeApi: true,
          fakeLatency: Duration.zero,
        ),
        cookieStore: stores.cookies,
        tokenStorage: stores.tokens,
      );
      addTearDown(layer.dispose);

      await layer.session.login(
        username: 'employee@example.invalid',
        password: 'demo-only',
      );
      expect(layer.session.state, isA<SessionAuthenticated>());
      expect(await stores.tokens.readAccessToken(), isNull);
      expect(await stores.cookies.isEmpty(), isTrue);

      expect(await layer.notifications.fetchUnreadCount(), 1);
    },
  );
}
