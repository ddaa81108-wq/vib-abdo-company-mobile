# Running against staging

The app talks only to the existing backend. This repository has no server and no database. The default launch uses the in-memory fake client and does not open a socket.

Real mode is for a **staging or test copy** of that backend. Do not point it at production, and do not commit the host, accounts, or passwords.

## Start

```bash
flutter run --dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://<staging-host>
```

The same defines work for `flutter build apk` and `flutter test`. `API_BASE` is read at compile time (`--dart-define`), not from the shell environment and not from a file in the repo.

`API_BASE` is the origin only:

- `https://staging.example.com`
- a trailing slash is stripped
- a non-default port is kept (`https://staging.example.com:8443`)

Startup throws `ApiConfigException` **before any request** when fake mode is off and the origin is missing, relative, not http(s), has a path (`/api`), a query, a fragment, or a username/password. The error text does not repeat the value you passed.

Fake mode (`USE_FAKE_API` omitted or `true`) ignores `API_BASE`.

Other defines, all optional:

| Define | Default | Role |
|---|---|---|
| `USE_FAKE_API` | `true` | `false` selects the Dio client |
| `API_BASE` | empty | Required origin when fake mode is off |
| `AUTH_BEARER` | `false` | `true` selects the bearer stub. The live server is cookie + CSRF until the owner says otherwise |
| `API_DEBUG_LOG` | `false` | Redacted request logs |
| `MONEY_UNIT_SCALE` | `0` | Fractional digits in `*Units`. Unconfirmed |
| `RATE_WIRE_FORMAT` | `number` | `string` sends rates as JSON strings |

Check the binary without a device:

```bash
flutter build apk --debug \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://<staging-host>
```

## What the real client does

Session is a cookie plus `X-CSRF-Token` (see `CookieCsrfAuthStrategy`).

- `POST /api/auth/login` is public. A `401` is invalid credentials and does not clear a session.
- Login is expected to return `data.csrfToken` and a `Set-Cookie` session.
- Later unsafe calls send the cookie and `X-CSRF-Token`.
- `GET /api/auth/csrf` refreshes the token when it is missing (memory only; it is not stored).
- A body whose code or message contains `CSRF` refreshes the token **once** and replays the request **once**. A second failure is not replayed.
- If that refresh itself returns `401` or `419`, the session is cleared instead of looping.
- An authenticated `401`, or a `419` that is not a CSRF failure, clears the cookie and the CSRF token and emits `session_expired`. The router sends the user to `/login` and shows "انتهت الجلسة، يرجى تسجيل الدخول". There is no refresh-token retry.
- `GET`/`HEAD` may retry connection failures and `502`/`503`/`504` (at most twice). `401` and `419` are never in that set. Mutations are not retried by the transport layer.
- SSE (`/api/events`) and polling (`/api/event-changes`) stop on `401`/`419` instead of reconnecting forever. Logout also stops them.

Errors use one mapper (`ErrorMapper`), then `ErrorHandler` for the UI:

| Failure | Result |
|---|---|
| DNS, connection, TLS | `NETWORK_UNAVAILABLE` |
| Connect, send, receive, or HTTP `408` | `TIMEOUT` |
| `400` with field details, or `422` | `VALIDATION_ERROR` plus each field message |
| Other `4xx` | The status's typed error and the server message when it sent one |
| `5xx` | `SERVER_ERROR` |
| Non-JSON body | The same status mapping; the HTML is not shown |

Logs keep the code and `correlationId` only.

## Tests

Unit tests use an in-process `HttpClientAdapter`. They do not call a host. From the repo root:

```bash
tool/check.sh
```

That runs `flutter analyze` and `flutter test` for the app and for `packages/api_layer`.

## Permission checks against staging

`tool/staging_negative_tests/run.sh` without `--dry-run` runs on the bot machine only. GitHub Actions calls that script only with `--dry-run`, which does not open a socket and does not read accounts. The required check `Negative permission tests` stays on the Fake API. No staging username or password is stored in GitHub as a secret or as a variable. The only staging name the smoke workflow reads is `STAGING_API_BASE`. See [TESTING.md](TESTING.md).

## P7-01 staging smoke

`packages/api_layer/test/phase7/staging_smoke_test.dart` is skipped unless all three variables are set. `tool/check.sh` and CI do not set them, and the test does not open a socket in that case. It uses the real client (`useFakeApi: false`) with no custom HTTP adapter.

```bash
STAGING_API_BASE=https://<staging-host> \
STAGING_ADMIN_USERNAME='<account>' \
STAGING_ADMIN_PASSWORD='<password>' \
flutter test packages/api_layer/test/phase7/staging_smoke_test.dart
```

`STAGING_API_BASE` is an origin only, same rules as `API_BASE`. The intended staging value is `https://staging.vip2100.com` with no `/erp` suffix. The password is read from the local environment and is not written into the repo. Do not store staging usernames or passwords in GitHub, neither as secrets nor as variables.

This login command runs on the bot machine only. GitHub Actions does not run it. The manual **Staging smoke** workflow (`.github/workflows/staging-smoke.yml`, `workflow_dispatch`, environment `staging`) only probes unauthenticated `GET /api/health`. `STAGING_API_BASE` for that job should be a secret. See [api/staging-smoke.ar.md](api/staging-smoke.ar.md).

**After a login failure, do not run this local check more than once within 15 minutes.** The login limit is 8 attempts per account. `STAGING_SMOKE_ACCOUNT_ID` stays unset until P-07.

The smoke signs in, reads `GET /api/me` (the client path; the phase-7 matrix text says `GET /api/auth/me`), reads one section (`STAGING_SMOKE_SECTION`, default `customers`), then `POST /api/auth/logout`. That logout is the write. Set `STAGING_SMOKE_ACCOUNT_ID` as well to send one `setPinned` of that card's current flag before logout. The smoke does not add a ledger line unless that id is set.

An on-device airplane-mode check (P7-19) is not this script. It is a manual pass on a release build.

## Open questions for the backend owner

These are assumed, not confirmed. The contract notes are outside this repository.

1. Is a staging origin available, and who issues the test accounts? Keep both outside the repo.
2. Does mobile stay on the cookie session, or will the bearer endpoints (`/api/auth/mobile/*`, currently a stub) exist?
3. CSRF: is `GET /api/auth/csrf` correct, and is the body `{ "ok": true, "data": { "csrfToken": "..." } }` with header `X-CSRF-Token`? Does `POST /api/auth/login` itself require a token?
4. Session expiry: which status and code should force a new login? This client treats authenticated `401` and non-CSRF `419` as expiry (`AUTH_REQUIRED` is the only code observed; `SESSION_EXPIRED`, `SESSION_REVOKED`, and `PAGE_EXPIRED` are defensive).
5. CSRF failure: which status and code? A code or message containing `CSRF` refreshes once. A bare `419` logs the user out.
6. Login failure: which `401` code means bad credentials rather than a dead session?
7. Validation: is it HTTP `422`, `400`, or both, and is `details` a `{ "fields": { "name": "..." } }` map, a flat map, or a list of `{ "field", "code", "message" }`?
8. Still unconfirmed on a real response: `fullAccess`, management permission codes, `cashStatus`, `GET /api/home`, `MONEY_UNIT_SCALE`, and whether rates are JSON numbers or strings.
9. P-15 / DEF-031: when a receipt or collection is approved and linked to an account whose currency differs from the receipt's, what does the server do? The Fake in PR #79 approves without posting a balance and omits `balanceUnits`. The error catalog has no code for this; `INVALID_LEDGER_CURRENCY` is only the financial-ledger query. Please confirm whether the server rejects (and with which code), converts, or posts nothing.
