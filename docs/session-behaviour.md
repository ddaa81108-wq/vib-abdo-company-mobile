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

The implementation is open [PR #38](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/38) (`cursor/session-expiry-logout-2f57`). This branch merges that code and does not keep a second expiry mapper.

| Response | Result |
|---|---|
| Authenticated 401, any code | Session expiry |
| Public login 401, any code, including `AUTH_REQUIRED` | Invalid credentials |
| 419 whose code or message contains `CSRF` | CSRF refresh, one replay |
| Any other 419, including a non-JSON body | Session expiry (`PAGE_EXPIRED` when the server sends no code) |
| `AUTH_REQUIRED`, `SESSION_EXPIRED`, `SESSION_REVOKED`, or `PAGE_EXPIRED` on another status | Session expiry |

Expiry calls `SessionManager.forceLogout`. Many 401s share one wipe. An explicit logout that overlaps those 401s keeps reason `logout`, so the login screen does not show the expiry notice. The router shows "انتهت الجلسة، يرجى تسجيل الدخول" only for reason `session_expired` and sends the user to `/login`.

`GET` / `HEAD` transport retries skip 401 and 419. They never retry `POST`, `PUT`, `PATCH`, or `DELETE`.

## Logout and local wipe

`POST /api/auth/logout` is sent with the cookie and `X-CSRF-Token` so the server can invalidate the session. The client then wipes all three local credentials even if that call failed:

- the cookie jar (`CookieStore.clear`)
- the token store (`TokenStorage.clear`), including a bearer token left from a stub experiment
- the in-memory CSRF token

`SessionManager` runs that wipe single-flight. Logout's own 401 does not announce `session_expired`. The same wipe runs on expiry. A later authenticated request has no cookie and no CSRF token. The fake answers 401 once `expireSession` has marked the cookie dead, and again after logout. The real server must do the same for a replayed cookie (question 8 in the totals proposal). If logout never reached the server, the server session can live until its own lifetime; the app will not send the cookie again.

## In-flight write at expiry

A write that is in flight when the session dies is **not** retried, and it is **not** replayed after the next login.

`pendingMutationProvider` keeps the `requestId`, the inputs, and the expected version for that user. The protected route is disposed by the login redirect, so the form's controllers are gone. The next `GuardedMutation` for the same user, the same inputs, and the same expected version reuses that `requestId`. A different user drops the snapshot. A successful send clears it. Nothing sends the write by itself after login.

The CSRF replay above is the only automatic replay of a write, and only when the server said the token was rejected. The body, including `requestId`, is unchanged. Question 9 in the totals proposal asks the server to treat `requestId` as idempotent if a write was applied and then the session died.

## What the code does

Verified against PR #38's `SessionManager`, `AuthInterceptor`, `ErrorMapper`, `ApiStack`, and `pendingMutationProvider`:

- Fake mode and cookie mode both clear the cookie jar, the token store, and the in-memory CSRF token on logout and on expiry.
- Bearer mode remains a stub and is not selected unless `AUTH_BEARER` is set. It has no refresh call.
- Tests: `packages/api_layer/test/permissions/session_permission_negative_test.dart` (from PR #38) and `packages/api_layer/test/permissions/session_wipe_permission_negative_test.dart`.
