# Security review

Review of session handling, permission-adjacent logging, notifications, secure storage, and data-leak prevention for the Flutter client. The app talks only to the existing backend. This pass did not add an auth protocol and did not rewrite git history.

Reviewed on 2026-10-20 against `main` (`fea12dd`). Severity is the impact if the issue is left as it was: **High** (credential or financial data leaves the device or the repo), **Medium** (a real leak path that needs a mistake or a later change to fire), **Low** (narrow or latent), **Info** (checked, no code change, or accepted).

## Findings

| ID | Severity | Location | Finding | Status |
|---|---|---|---|---|
| SR-1 | Medium | `packages/api_layer/lib/core/security/redactor.dart` | Key matching was an exact lowercase set. `current_password`, `access_token`, `X-CSRF-Token`, `createdByName`, `displayNote`, `systemNote`, `email`, `loginTicket`, notification `body` / `message`, and amount fields such as `openingBalance` and `factorMicros` were not covered. A string value was returned unchanged, so a `Bearer` token, JWT, URL userinfo, or `password=` / `cookie=` assignment survived. | **Fixed.** Keys are matched with case and `_` / `-` ignored, plus name, note, token, cookie, password, phone, email, and amount rules. `correlationId` and `x-correlation-id` stay. Secret-shaped text is scrubbed. |
| SR-2 | Medium | `lib/main.dart`, `lib/error_handling/error_handler.dart` | `ErrorHandler.report` logs only `code` and `correlationId`, but `FlutterError.onError` then called `FlutterError.presentError`, which dumps the exception and stack. The handler comment says stacks are not printed because a frame can hold a field value. | **Fixed.** Framework and platform errors go through `installErrorHooks` → `report` only. The log line is scrubbed. A `Bearer` token or `password=` assignment inside a server message is removed before the UI shows it. Ordinary Arabic text is left as the server sent it. |
| SR-3 | Medium | `lib/main.dart`, `packages/api_layer/lib/api_layer.dart`, `core/session/session_manager.dart` | Logout and `AUTH_REQUIRED` call `AuthStrategy.clear()`. The cookie strategy clears the cookie jar and the in-memory CSRF token. The bearer stub clears tokens. `main` always constructs both stores. The store the active strategy does not use, including its memory cache, was not wiped. A leftover cookie would be treated as a persisted session if the process later ran the cookie strategy. | **Fixed.** `ApiLayer.create` registers a cleanup that clears both injected stores on logout and on forced expiry (the same `_wipe` path). |
| SR-4 | Low | `packages/api_layer/lib/core/auth/cookie_store.dart` | Expired cookies were omitted from the `Cookie` header but could remain inside the encrypted jar until the next write. | **Fixed.** Loading or building the header deletes expired and corrupt entries from storage. `clear()` still deletes the whole key. |
| SR-5 | Low | `packages/api_layer/lib/core/network/logging_interceptor.dart` | The interceptor never logged headers, bodies, or the query. Its constructor default was `kDebugMode`, so a direct `SafeLoggingInterceptor()` would log in every debug build. The factory already passes `ApiConfig.enableDebugLogging`, which is off unless `--dart-define=API_DEBUG_LOG=true`. | **Fixed.** The default is off. When logging is on, the line is method, path, status, correlation id, retry, and duration. Query, userinfo, and host are not included, and the line is scrubbed (including a correlation id that looks like `session=…`). |
| SR-6 | Low | `core/security/screen_security.dart`, `android/.../MainActivity.kt` | `FLAG_SECURE` is set on the activity window in `onCreate` and again when the engine is configured, so screenshots are blocked and the recents thumbnail is blank for the whole task. The Dart type was a no-op, and nothing called the `app/screen_security` channel. The channel only implements `enable`. | **Fixed.** `PlatformScreenSecurity.enable` calls that channel from `main` and again whenever the app resumes. `disable` does not clear the flag. There is no per-screen blur: Android's flag is window-wide, which is what this app needs because login, lists, ledgers, collections, purchases, treasury, reports, search, and notifications can all show a password, a name, or an amount. |
| SR-7 | Low | `android/app/src/main/AndroidManifest.xml` | `android:allowBackup` was unset. The platform default is to allow backup. Session cookies live in encrypted storage; the keystore key is not part of a backup, so another device cannot decrypt them. A restore onto the same device could still bring a session back after logout. | **Fixed.** `android:allowBackup="false"`. This does not delete a backup the device already made. |
| SR-8 | Info | `lib/state/theme_controller.dart` | `SharedPreferences` is used for one key, `app-theme`, with values `light` or `dark`. No token, cookie, password, name, or amount is written there. No other plain file or database write exists. PDF export is fake-only and does not save a file. Push is a no-op. Realtime signals are ignored; the app refetches. | No change. Locked with `test/secure_storage/preferences_scope_test.dart`. |
| SR-9 | Info | Repository and git history (`9ac30e9`…`fea12dd`) | No `.env`, keystore, `google-services.json`, private key, or live token file is tracked. History was searched for private-key blocks, common cloud key prefixes, and JWTs. The only `keystore` hits are gitignore rules and comments. Fixture passwords (`wrong`, `demo-only`, `x`) and `fake-csrf` are fake. The API origin defaults to `https://staging.example.invalid`. | No history rewrite. |
| SR-10 | Info | `lib/error_handling/error_handler.dart` | The UI still shows the server's `error.message` after the secret-shaped scrub. A message that contains a customer name, phone, or email is shown to the signed-in user. It is not written to the log. `error.details` is not shown and not logged. | Accepted. Ask the backend not to echo secrets in `message` (question 4). |
| SR-11 | Info | `core/network/api_client_factory.dart` | TLS pinning is a comment. The client trusts the platform trust store. Cleartext is not enabled in the manifest; `targetSdk` follows Flutter, which blocks cleartext HTTP by default. | Open until the backend supplies pins (question 6). |
| SR-12 | Info | `core/auth/cookie_store.dart` | `Path`, `Domain`, and `Secure` on `Set-Cookie` are not enforced. Every stored cookie is sent on every path of the single configured origin. Cookies are not sent to any other host. | Accepted for a single-origin client. Confirm the cookie flags (question 2). |
| SR-13 | Info | `android/app/build.gradle.kts`, `README.md` | Release builds are signed with the debug key. The application id is `com.example.vib_abdo_company_mobile`. | Open launch item. A production keystore must not be committed. |
| SR-14 | Info | Repository layout | There is no iOS target, so there is no iOS app-switcher overlay. | Open only if iOS is in scope. |

## What is already sound

- CSRF is memory-only. After a restart the client refetches it with `GET /api/auth/csrf` and does not write it to disk.
- Cookies and bearer tokens (when a token strategy is actually used) go through `flutter_secure_storage` with Android encrypted storage and iOS `first_unlock_this_device`. Tests use the in-memory fakes. The fake API client does not write either store.
- `ApiException.toString` is code, status, and correlation id. `details` stays off that string.
- `SafeLoggingInterceptor` is the only HTTP log, and it is off unless `API_DEBUG_LOG` is set. There is no Dio `LogInterceptor`.
- `SessionManager._wipe` runs for logout, `AUTH_REQUIRED`, and a failed restore. It clears the strategy, permissions, realtime, and the push token hook, then the both-stores cleanup above.
- Permission checks hide controls. The server is still the enforcement point. This review did not change that.

## Auth recommendation

**Keep cookie + CSRF. Leave `AUTH_BEARER` off.**

The server that exists today is a browser session: `POST /api/auth/login` sets a cookie and returns `csrfToken`, and unsafe methods need `X-CSRF-Token`. There is no mobile login, no refresh, and no bearer logout. `BearerTokenAuthStrategy` is a stub. It stores tokens only if the login JSON contains `accessToken` and `refreshToken`, which this login does not, and it does not refresh. Turning the flag on would not produce a working, or a safer, session. The client is required to use the existing API, so it cannot invent a token scheme by itself.

Cookie + CSRF is a sound fit for **this** client for as long as that is the server's only session:

- The app is not a browser. It stores the cookie itself and attaches `Cookie` only on the configured API origin. Another website cannot ride that cookie the way it can in a browser.
- The server still requires the CSRF header, and the client already sends it on every non-GET, refetches it once on a CSRF failure, and drops it on logout. Keeping the token in memory, not in storage, is the right split.
- Session expiry is `AUTH_REQUIRED` (and any other 401 that is not a bad-password code). There is no refresh. That matches the server. Forced logout now wipes both stores.

Bearer is the better **mobile** design if the backend adds it, and only then:

- One `Authorization` header, no second secret to keep in sync with the cookie, and no hand-rolled cookie jar. The jar ignores `Path` and `Domain` (SR-12).
- A short-lived access token plus a rotating refresh token in the keystore limits the value of a stolen access token. The cookie session lives until the server expires it or the user logs out.
- The stub's storage and the logout wipe are already in place. They are not a reason to send `AUTH_BEARER` against today's server.

Do not run both. If a bearer API appears, the server should stop accepting the old cookie from this client so a leftover cookie cannot resume the previous session.

## Questions for the backend owner

1. Will the server add a mobile token API (`POST /api/auth/mobile/login`, refresh with rotation, logout that revokes the refresh token)? If it will not, cookie + CSRF stays the only supported scheme and `AUTH_BEARER` stays off. If it will, what are the field names, lifetimes, and the rotation rule (is the previous refresh token rejected on reuse)?
2. What cookie does login set today (name, `Secure`, `HttpOnly`, `SameSite`, `Path`, `Domain`, `Max-Age`)? The client stores every `Set-Cookie` for the one origin and sends it on every API path.
3. What is the CSRF error code? Any code containing `CSRF` is treated as a CSRF failure and refetched once. What is the session lifetime, and is `AUTH_REQUIRED` the only expiry signal?
4. Can `error.message` or `error.details` echo the submitted password, token, cookie, phone, or customer name? The UI shows `message` after a secret-shaped scrub. `details` is dropped.
5. Will this client ever be a WebView that shares the website cookie jar? If yes, cookie flags and CSRF have to stay correct in the browser sense. If no, a bearer scheme is the cleaner mobile contract.
6. Is the staging host HTTPS only, and will you supply SPKI pins? The client does not pin certificates.
7. After a bearer scheme exists, will the server reject cookie sessions from this client so an old cookie cannot sign the user back in?

## Tests

- `packages/api_layer/test/redactor_test.dart`
- `packages/api_layer/test/logging_interceptor_test.dart`
- `packages/api_layer/test/cookie_expiry_test.dart`
- `packages/api_layer/test/session_wipe_test.dart`
- `test/error_handling/error_handler_test.dart` (extended)
- `test/security/screen_protection_test.dart`
- `test/secure_storage/preferences_scope_test.dart`
