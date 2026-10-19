# flutter_api_layer (v0.2 — aligned with the real system)

Backend client for the company app (cookie session + X-CSRF-Token, `{ok,data}` envelope, `*Units` integer money, SSE). Contract notes stay outside this repository.

- Fake mode (default, no network): `--dart-define=USE_FAKE_API=true`
  - Fixture by username (fake only): `admin…` => role "admin" with EMPTY lists, like the real server today (full access via the role flag); `limited.admin…` => admin with explicit lists (lists apply); `flag.admin…` => admin with `fullAccess:false` (nothing); `guest…` => unknown role (nothing); anything else => collections employee. Password `wrong` => 401.
- Real (staging/test copy ONLY): `--dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://<staging-host>`
- Bearer stub (pending server answer): `--dart-define=AUTH_BEARER=true`
- `--dart-define=MONEY_UNIT_SCALE=0` (default; to confirm)

RULE: no business calculations anywhere. `*Units` are raw ints; rates are `DecimalString` (text, no double); displayed only via `MoneyFormatter`, one value + its own currency.
Permissions (final PM rule): server `role` matched EXACTLY (`"admin"`/`"employee"`) ONLY inside PermissionService; precedence fullAccess > explicit non-empty lists > admin role flag; unknown role = nothing; disallowed controls are HIDDEN.
- `--dart-define=RATE_WIRE_FORMAT=string` (default `number`): wire encoding of rates only; inside the app they are DecimalString text.

Verified on the box: `flutter analyze --no-pub` -> No issues; `flutter test --no-pub` -> 19 passed (offline).
