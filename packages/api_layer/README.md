# flutter_api_layer (v0.2 — aligned with the real system)

Backend client (cookie session + X-CSRF-Token, `{ok,data}` envelope, `*Units` integer money, SSE).
Behavior follows the API contract. Contract notes stay outside this repository.

- Fake mode (default, no network): `--dart-define=USE_FAKE_API=true`
  - Fixture by username (fake only): `admin…` => role "admin" with EMPTY lists, like the real server today (full access via the role flag); `limited.admin…` => admin with explicit lists (lists apply); `flag.admin…` => admin with `fullAccess:false` (nothing); `guest…` => unknown role (nothing); `mustchange…` => collections employee with `mustChangePassword: true` until change-password succeeds; anything else => collections employee. Password `wrong` => 401.
  - Section reads and writes return 403 when the profile does not allow them. `GET /api/home` returns only sections that profile can read, and its amounts are the same literals as the section fixtures (customers net `10635` / count `10`, Egyptian deposits net `23750`). A repeated `requestId` returns the first success and is not applied again. Each account section has 10 cards; `c_55` is the original demo card; customers include `c_masraweya_remainder` (`systemManaged: true`). Card ages use one label for `debtAgeDays` (`منذ N أيام`), including the home bulletin for `c_55`.
- Real (staging/test copy ONLY): `--dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://<staging-host>`
- Bearer stub (pending server answer): `--dart-define=AUTH_BEARER=true`
- `--dart-define=MONEY_UNIT_SCALE=0` (default; to confirm)

RULE: no business calculations anywhere. `*Units` are raw ints; rates are `DecimalString` (text, no double); displayed only via `MoneyFormatter`, one value + its own currency.
Permissions (final PM rule): server `role` matched EXACTLY (`"admin"`/`"employee"`) ONLY inside PermissionService; precedence (permission_service.dart L50-69): unknown/missing role = nothing; else fullAccess if sent; else admin with BOTH lists empty = full; else lists (write needs code AND manage; reports never writable; collections by codes only); disallowed controls are HIDDEN.
- `--dart-define=RATE_WIRE_FORMAT=string` (default `number`): wire encoding of rates only; inside the app they are DecimalString text.

Verified on the box: `flutter analyze --no-pub` -> No issues; `flutter test --no-pub` -> 46 passed (offline).
