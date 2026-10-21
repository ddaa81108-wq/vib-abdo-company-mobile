# Session behaviour (cookie + CSRF)

There is no refresh token. `POST /api/auth/mobile/login`, `POST /api/auth/mobile/refresh`, and `POST /api/auth/mobile/logout` are a stub. `AUTH_BEARER` stays off. The live client is cookie + `X-CSRF-Token` only.

The session lifetime is unknown (contract-gap item 42). The app has no local timer. A cookie with no `expires` / `Max-Age` stays in the secure jar until logout, until the server says the session is dead, or until a stored `expires` / `Max-Age` is in the past. That last check is cookie-jar bookkeeping, not a session clock.

## Login

`POST /api/auth/login` with `{username, password}` is sent with `skipAuth` (public). The server sets the session cookie. The body carries `csrfToken`. The token is kept in memory only. After a process restart the app calls `GET /api/auth/csrf` and then `GET /api/me`.

A **login 401 is bad credentials**, including when the code is `AUTH_REQUIRED`. It does not clear a cookie or the token store, and it does not emit `session_expired`.

## CSRF

Unsafe methods (`POST`, `PUT`, `PATCH`, `DELETE`) send `X-CSRF-Token` when the in-memory token is present. `GET` and `HEAD` do not. A code **or a server message** containing `CSRF` refreshes `GET /api/auth/csrf` once (single-flight) and replays that request once, with the same body and the same `requestId`. If the refresh itself returns 401 or 419, or the replay returns 401 or 419, the session ends and the write is not sent again.

## Expiry

Only `AUTH_REQUIRED` has been observed. `SESSION_EXPIRED`, `SESSION_REVOKED`, and `PAGE_EXPIRED` are defensive.

Classification matches the staging client:

| Response | Result |
|---|---|
| Authenticated 401, any code except one that contains `CREDENTIALS` or `LOGIN` | Session expiry |
| Authenticated 401 whose code contains `CREDENTIALS` or `LOGIN` | Invalid credentials, session kept (wrong current password must not look like expiry if the server uses that code) |
| Public login 401, any code | Invalid credentials |
| 419 whose code or message contains `CSRF` | CSRF refresh, one replay |
| Any other 419, including a non-JSON body | Session expiry (`PAGE_EXPIRED` when the server sends no code) |
| `AUTH_REQUIRED`, `SESSION_EXPIRED`, `SESSION_REVOKED`, or `PAGE_EXPIRED` on another status | Session expiry |

Expiry calls `SessionManager.forceLogout('session_expired')`. The router shows "انتهت الجلسة، يرجى تسجيل الدخول" and sends the user to `/login`. SSE and the 4-second poll stop on 401/419. They do not reconnect on a dead cookie.

`GET` / `HEAD` transport retries still skip 401 and 419. They never retry `POST`, `PUT`, `PATCH`, or `DELETE`.

## Logout and local wipe

`POST /api/auth/logout` is sent with the cookie and `X-CSRF-Token` so the server can invalidate the session. The client then wipes all three local credentials even if that call failed:

- the cookie jar (`CookieStore.clear`)
- the token store (`TokenStorage.clear`), including a bearer token left from a stub experiment
- the in-memory CSRF token

The same wipe runs on expiry. A later authenticated request has no cookie and no CSRF token. The fake server answers 401 `AUTH_REQUIRED` once its logged-in flag is cleared. The real server must do the same for a replayed cookie (question 55). If logout never reached the server, the server session can live until its own lifetime; the app will not send the cookie again.

## In-flight write at expiry

A write that is in flight when the session dies is **not** retried, and it is **not** replayed after the next login.

The interceptor logs the user out and surfaces the error. `GuardedMutation` shows "لم يُحفظ. انتهت الجلسة. أعد المحاولة بعد تسجيل الدخول." and does not start a new `requestId` while that same form is still mounted. A manual retry of the unchanged form sends the original `requestId`. The router then replaces the screen with `/login`, so the form is usually disposed and the id is not stored on disk. The client will not send the write by itself after login. A later new submission is a new user action and a new id.

The CSRF replay above is the only automatic replay of a write, and only when the server said the token was rejected. The body, including `requestId`, is unchanged. Question 56 asks the server to treat `requestId` as idempotent if a write was applied and then the session died.

## What the code does

Verified in `CookieCsrfAuthStrategy`, `AuthInterceptor`, `GetRetryInterceptor`, `ErrorMapper`, `SessionManager`, and `ApiStack`:

- Cookie mode clears the cookie jar and the CSRF token. `ApiStack` also clears the token store on every logout and expiry, in fake mode and in real mode.
- Bearer mode remains a stub and is not selected unless `AUTH_BEARER` is set. It has no refresh call.
- Tests: `packages/api_layer/test/permissions/session_wipe_permission_negative_test.dart` and the write-not-saved case in `test/guarded_mutation_test.dart`.
