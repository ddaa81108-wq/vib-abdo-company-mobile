import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout is signed out before permissions are cleared', () async {
    final api = ApiLayer.create(
      config: const ApiConfig(
        baseUrl: 'https://fake.invalid',
        useFakeApi: true,
      ),
      fakeLatency: Duration.zero,
    );
    addTearDown(api.dispose);
    await api.session.login(username: 'admin.demo', password: 'demo-only');
    expect(api.session.state, isA<SessionAuthenticated>());
    expect(api.permissions.canRead(SectionKey.purchases), isTrue);

    var clearedWhileSignedIn = false;
    api.permissions.addListener(() {
      if (api.session.state is SessionAuthenticated) {
        clearedWhileSignedIn = true;
      }
    });

    await api.session.logout();

    expect(clearedWhileSignedIn, isFalse);
    expect(api.session.state, isA<SessionUnauthenticated>());
    expect(
      (api.session.state as SessionUnauthenticated).reason,
      'logout',
    );
    expect(api.permissions.canRead(SectionKey.purchases), isFalse);
    expect(api.permissions.canRead(SectionKey.collections), isFalse);
  });
}
