import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// P7-01. Live staging smoke. Skipped unless the operator passes credentials
/// in the environment. CI does not set them, and this file does not use
/// [FakeApiClient] or a hand-written [HttpClientAdapter].
///
/// The cookie jar is [InMemoryCookieStore] so a local bot run can keep the
/// session without Keychain. The app default remains [SecureCookieStore].
/// Requests use the real Dio client, whose `dart:io` User-Agent is not
/// Python-urllib. GitHub skips this test before the client is created.
///
/// ```bash
/// STAGING_API_BASE=https://staging.example.invalid \
/// STAGING_ADMIN_USERNAME=... \
/// STAGING_ADMIN_PASSWORD=... \
/// flutter test packages/api_layer/test/phase7/staging_smoke_test.dart
/// ```
///
/// Optional `STAGING_SMOKE_SECTION` (default `customers`).
/// `STAGING_SMOKE_ACCOUNT_ID` is not read. `setPinned` was removed: a read
/// of the card would not cover the P-07 pin body, so that write stays
/// deferred until Ali decides. The only write on the bot machine is
/// `POST /api/auth/logout`. No ledger line is created.
///
/// The client calls `GET /api/me`. The matrix text says `GET /api/auth/me`.
/// GitHub never runs the body: any non-empty `CI` or `GITHUB_ACTIONS` skips
/// before a client is created.
void main() {
  test(
    'P7-01 staging smoke: login, GET /api/me, one section read, logout',
    () async {
      if (_githubHosted(Platform.environment)) {
        markTestSkipped(
          'GitHub does not run the staging login smoke and does not send '
          'writes. CI and GITHUB_ACTIONS must be empty.',
        );
        return;
      }
      final base = Platform.environment['STAGING_API_BASE'] ?? '';
      final username = Platform.environment['STAGING_ADMIN_USERNAME'] ?? '';
      final password = Platform.environment['STAGING_ADMIN_PASSWORD'] ?? '';
      if (base.isEmpty || username.isEmpty || password.isEmpty) {
        markTestSkipped(
          'P7-01 is opt-in. Set STAGING_API_BASE, STAGING_ADMIN_USERNAME, '
          'and STAGING_ADMIN_PASSWORD. CI does not set them.',
        );
        return;
      }
      final sectionName =
          Platform.environment['STAGING_SMOKE_SECTION'] ?? 'customers';
      final section = AccountSection.values.firstWhere(
        (item) => item.path == sectionName,
        orElse: () => AccountSection.customers,
      );
      final layer = ApiLayer.create(
        config: ApiConfig(baseUrl: base, useFakeApi: false),
        cookieStore: InMemoryCookieStore(),
      );
      try {
        await layer.session.login(username: username, password: password);
        expect(layer.session.state, isA<SessionAuthenticated>());
        final me = layer.session.currentUser;
        expect(me, isNotNull);
        expect(me!.id, isNotEmpty);
        final page = await layer.accounts.list(section, limit: 1);
        expect(page.page.items, isA<List<AccountCardDto>>());
        await layer.session.logout();
        expect(
          layer.session.state,
          isA<SessionUnauthenticated>().having(
            (state) => state.reason,
            'reason',
            'logout',
          ),
        );
      } finally {
        await layer.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('P7-01 does not run when CI or GITHUB_ACTIONS is non-empty', () {
    for (final value in ['true', '1', 'false', 'yes']) {
      expect(_githubHosted({'CI': value}), isTrue);
      expect(_githubHosted({'GITHUB_ACTIONS': value}), isTrue);
    }
    expect(_githubHosted({}), isFalse);
    expect(_githubHosted({'CI': ''}), isFalse);
    expect(_githubHosted({'GITHUB_ACTIONS': ''}), isFalse);
    expect(_githubHosted({'CI': '   '}), isFalse);
  });
}

bool _githubHosted(Map<String, String> env) {
  bool blocks(String key) => (env[key] ?? '').trim().isNotEmpty;
  return blocks('CI') || blocks('GITHUB_ACTIONS');
}
