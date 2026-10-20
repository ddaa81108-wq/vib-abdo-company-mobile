import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout and session expiry wipe both injected stores', () async {
    final cookies = InMemoryCookieStore();
    final tokens = InMemoryTokenStorage();
    await cookies.saveFromSetCookie(['session=fake-session']);
    await tokens.saveTokens(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
    );

    final layer = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      cookieStore: cookies,
      tokenStorage: tokens,
      fakeLatency: Duration.zero,
    );
    addTearDown(layer.dispose);

    await layer.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );
    await layer.session.logout();
    expect(layer.session.state, isA<SessionUnauthenticated>());
    expect((layer.session.state as SessionUnauthenticated).reason, 'logout');
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);

    await cookies.saveFromSetCookie(['session=again']);
    await tokens.saveTokens(accessToken: 'a2', refreshToken: 'r2');
    await layer.session.login(
      username: 'employee@example.invalid',
      password: 'x',
    );
    await layer.session.forceLogout('session_expired');
    expect(
      (layer.session.state as SessionUnauthenticated).reason,
      'session_expired',
    );
    expect(await cookies.isEmpty(), isTrue);
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });
}
