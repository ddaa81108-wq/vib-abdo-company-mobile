import 'dart:io';

import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// P7-01. Live staging smoke. Skipped unless the operator passes credentials
/// in the environment. CI does not set them, and this file does not use
/// [FakeApiClient] or a hand-written [HttpClientAdapter].
///
/// The cookie jar is [InMemoryCookieStore] so `flutter test` on a GitHub
/// runner can keep the session without Keychain. The app default remains
/// [SecureCookieStore]. Requests use the real Dio client, whose `dart:io`
/// User-Agent is not Python-urllib.
///
/// ```bash
/// STAGING_API_BASE=https://staging.example.invalid \
/// STAGING_ADMIN_USERNAME=... \
/// STAGING_ADMIN_PASSWORD=... \
/// flutter test packages/api_layer/test/phase7/staging_smoke_test.dart
/// ```
///
/// Optional `STAGING_SMOKE_SECTION` (default `customers`).
/// Optional `STAGING_SMOKE_ACCOUNT_ID` also sends one `setPinned` of the
/// card's current flag before logout. Without it, the write is
/// `POST /api/auth/logout`. No ledger line is created unless that id is set.
///
/// The client calls `GET /api/me`. The matrix text says `GET /api/auth/me`.
void main() {
  test(
    'P7-01 staging smoke: login, GET /api/me, one section read, one write',
    () async {
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
        final accountId = Platform.environment['STAGING_SMOKE_ACCOUNT_ID'];
        if (accountId != null && accountId.isNotEmpty) {
          final card = await layer.accounts.get(section, accountId);
          await layer.accounts.setPinned(
            section,
            accountId,
            card.pinned,
            MutationMeta(expectedVersion: card.version),
          );
        }
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
}
