# flutter_api_layer (v0.2 — aligned with the real system)

Backend client (cookie session + X-CSRF-Token, `{ok,data}` envelope, `*Units` integer money, SSE).
Behavior follows the API contract. Contract notes stay outside this repository.

- Fake mode (default, no network): `--dart-define=USE_FAKE_API=true`
  - Fixture by username (fake only): `admin…` => role "admin" with EMPTY lists, like the real server today (full access via the role flag); `limited.admin…` => admin with explicit lists (lists apply); `flag.admin…` => admin with `fullAccess:false` (nothing); `guest…` => unknown role (nothing); anything else => collections employee. Password `wrong` => 401.
- Real (staging/test copy ONLY): `--dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://<staging-host>`
- Bearer stub (pending server answer): `--dart-define=AUTH_BEARER=true`
- `--dart-define=MONEY_UNIT_SCALE=0` (default; to confirm)

RULE: no business calculations anywhere. `*Units` are raw ints; rates are `DecimalString` (text, no double); displayed only via `MoneyFormatter`, one value + its own currency.
Permissions (final PM rule): server `role` matched EXACTLY (`"admin"`/`"employee"`) ONLY inside PermissionService; precedence (permission_service.dart L50-69): unknown/missing role = nothing; else fullAccess if sent; else admin with BOTH lists empty = full; else lists (write needs code AND manage; reports never writable; collections by codes only); disallowed controls are HIDDEN.
- `--dart-define=RATE_WIRE_FORMAT=string` (default `number`): wire encoding of rates only; inside the app they are DecimalString text.

Named environments (`fake`, `staging`, and a reserved `prod` placeholder) are JSON files under `config/dart_defines/` at the repository root, passed with `--dart-define-from-file`. See `../../docs/ENVIRONMENTS.md`. The defines above are unchanged.

Verified on the box: `flutter analyze --no-pub` -> No issues; `flutter test --no-pub` -> 46 passed (offline).
