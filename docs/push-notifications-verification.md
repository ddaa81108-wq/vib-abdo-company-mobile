# Push notifications verification

Phase 6, step 1. Read-only check of whether this app and the API contract it already calls can deliver push. No application code is changed here, and no new backend route is proposed as something to build in this step.

**Base:** `main` at `8a52160`, the same commit as `origin/main` at the time of writing.
**This repository is the Android client only.** It does not contain the server. Nothing in this run called a live host. `API_BASE` is empty in fake mode and has no default host (`README.md`).

How the words below are used:

| Word | Meaning in this note |
|---|---|
| Confirmed (client contract) | The current client calls or parses it, and `api_endpoints.dart` does not list it under "Proposed paths. The server does not implement these yet." This is not a capture from the live server and not a sign-off from the backend owner. |
| Differs | The senior engineer's draft contract and the client on `main` disagree. |
| Unknown | Only a comment, a fake fixture, or an open question. Conclusions beyond the quoted lines are marked **inferred**. |

Open questions 17, 18, and 19 already cover unread-count, `title`/`body`, and mobile device registration. They live in PR #5 (`docs/api-contract-gaps.md` on `cursor/api-contract-gaps-cfdc`, not on `main`). That PR's line numbers are against an older `main` (`fea12dd`) and are not reused here. The questions themselves are still unanswered (the PR is open).

## (a) Verdict: not supported

Push to this app is **not supported**.

- There is no FCM, APNs, or web-push client, and no device-token call.
- The only mobile registration path in the tree is `POST /api/mobile-push/devices`, declared as proposed and not called. The comment above it says the server does not implement that group yet (`packages/api_layer/lib/core/network/api_endpoints.dart:117-119`). The permission matrix lists it under "Declared and not called" (`docs/permission-enforcement-matrix.md:135-143`).
- `PushService` is a no-op. `getToken()` returns null and `messages` is an empty stream (`packages/api_layer/lib/core/push/push_service.dart:18-25`). `main` installs that no-op (`lib/main.dart:34`, `lib/notifications/app_push_service.dart:5-9`).
- A comment says the server today has web push at `/api/browser-push/*` (VAPID + service worker) and that it cannot be used by a native app, and the next line says this is pending server confirmation (`packages/api_layer/lib/core/push/push_service.dart:1-4`). That path is not a constant, and a repo search finds the string only in that comment. **Web push is unknown, not confirmed.** Question 19 asks the owner to confirm or reject it.

Foreground refresh exists (section b). It is an in-app signal while the process is alive. It is not push.

### Evidence searched

| Check | Result |
|---|---|
| Root `pubspec.yaml` dependencies | `flutter`, `flutter_localizations`, `flutter_api_layer`, `flutter_riverpod`, `go_router`, `shared_preferences` (`pubspec.yaml:9-18`). No `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, or `workmanager`. |
| `packages/api_layer/pubspec.yaml` | `dio`, `flutter_secure_storage`, `uuid` (`packages/api_layer/pubspec.yaml:10-15`). |
| Gradle plugins | `com.android.application`, Kotlin, Flutter (`android/settings.gradle.kts:20-24`, `android/app/build.gradle.kts:1-5`). No Google Services plugin. |
| `android/app/google-services.json`, `GoogleService-Info.plist`, `ios/` | Not in the tree. |
| Manifest permissions | `INTERNET` and `ACCESS_NETWORK_STATE` only (`android/app/src/main/AndroidManifest.xml:2-3`). No `POST_NOTIFICATIONS`, no FCM service, no boot receiver. |
| Application id | `com.vip2100.vib` (`namespace` and `applicationId` in `android/app/build.gradle.kts`; was `com.example.vib_abdo_company_mobile` before Phase 9). |
| Token registration call | `proposedMobilePushDevices` is defined at `api_endpoints.dart:119` and has no other reference. `deleteToken` on logout calls the no-op (`packages/api_layer/lib/api_layer.dart:158`). |
| Push payload type | `PushMessage` is `type` plus optional `entityId` (`push_service.dart:6-9`). The rule in the same file: a push is a signal, never numbers to display. |

`README.md:16` states the same rule for the badge: a realtime event or a push message, when one exists, only triggers a refetch of `unreadCount`. `README.md:40` describes `lib/notifications/` as "Unread badge, no-op push, realtime start/stop".

## (b) In-app (foreground) delivery today

Delivery while the user is signed in and the Flutter process is in the foreground is **confirmed as client behavior** for the real HTTP client. Fake mode does not start it: the fake stack leaves `dio` null so realtime is a no-op (`packages/api_layer/lib/core/network/api_client_factory.dart:59-60`, `packages/api_layer/lib/api_layer.dart:131-132`).

### When it runs

`RealtimeLifecycle` starts the client only when the session is `SessionAuthenticated` and the lifecycle is not `paused`, `detached`, or `hidden` (`lib/notifications/realtime_lifecycle.dart:52-60`). Leaving that state cancels both subscriptions and calls `realtime.stop()` (`realtime_lifecycle.dart:76-82`). The widget wraps the app (`lib/app.dart:76-77`).

**Inferred:** an Android app that has left the screen is `paused` or `hidden`, so the 4-second poll and SSE stop as soon as the app is backgrounded. They do not keep running until the process is killed.

### SSE

`GET /api/events?after=<seq>` (`api_endpoints.dart:110`, `packages/api_layer/lib/core/realtime/sse_realtime_service.dart:94-103`).

- Header `Accept: text/event-stream`. The call uses the same Dio as the API, so the session cookie is attached (`sse_realtime_service.dart:12-13`, `94-103`).
- Opening the stream emits a resync signal (`sse_realtime_service.dart:110-111`).
- SSE `event:` is the topic. SSE `id:` is parsed as an integer sequence. Missing, non-numeric, or `<= 0` becomes another resync and does not produce a sequenced signal (`sse_realtime_service.dart:141-150`).
- The `data:` JSON is read only for a string `aggregateId`. `payload` is ignored (`sse_realtime_service.dart:154-163`).
- Known topics are the `*.changed` names in `RealtimeTopics` (`packages/api_layer/lib/core/realtime/realtime_service.dart:25-55`). There is no notification topic and no `notificationId`.
- `401` / `419` ends the reconnect loop (`sse_realtime_service.dart:73-75`). Other failures back off from 1s toward 30s (`sse_realtime_service.dart:86-89`).
- `docs/staging.md` records the same stop-on-401/419 behavior.

### Polling fallback

`GET /api/event-changes?after=<seq>` every 4 seconds unless a caller overrides the interval (`api_endpoints.dart:111`, `packages/api_layer/lib/core/config/api_config.dart:55`, `api_config.dart:70-71`, `packages/api_layer/lib/core/realtime/polling_realtime_service.dart:9-15`).

Response shape the client expects (`polling_realtime_service.dart:9-10`, `56-72`):

```text
{ events: [{ sequence, topic, aggregateId, payload, createdAt }], latest, fullResync }
```

The client reads `sequence`, `topic`, `aggregateId`, `latest`, and `fullResync`. It does not read `payload` or `createdAt`. `fullResync == true` emits a resync. `401` / `419` stops the timer (`polling_realtime_service.dart:73-76`).

`ResilientRealtimeService` runs polling until SSE reports connected, then stops polling, and starts it again when SSE drops (`packages/api_layer/lib/core/realtime/resilient_realtime_service.dart:7-8`, `32-41`).

Permission matrix: both routes are "any signed-in user", events for records in scope (`docs/permission-enforcement-matrix.md:120-121`).

### notificationId and dedup

There is no field named `notificationId` anywhere in this repository.

| Stream | Dedup key | What it is not |
|---|---|---|
| SSE | Integer in the SSE `id:` line, stored as `RealtimeSignal.sequence` | Not a notification id. A bad id becomes a resync, which is not deduped. |
| Polling | Integer `events[].sequence`, then `latest` advances the same cursor | `aggregateId` is forwarded and then ignored by the listener. |
| Merged stream | `ResilientRealtimeService` drops a signal when `sequence <= _lastEmitted`. A `fullResync` signal is always forwarded (`resilient_realtime_service.dart:44-51`). | Dedup state is in memory. Logout sets it back to 0 (`resilient_realtime_service.dart:65-66`, `api_layer.dart:152-157`). |
| Notification list | Item field `id` (`notification_models.dart:9`, `28`) | Used as the read URL and the widget key (`notifications_screen.dart:96`, `150`). The realtime listener does not see it. |
| Push | None. The stream is empty. | `PushMessage` has no id (`push_service.dart:6-9`). |

The listener discards the signal object. On a realtime signal it invalidates `unreadCountProvider`, `homeDashboardProvider`, `collectionsProvider`, and `ledgerProvider` (`realtime_lifecycle.dart:63-68`). It does not invalidate `notificationsProvider`. On a push message it invalidates `unreadCountProvider` only (`realtime_lifecycle.dart:70-72`).

The badge number is `unreadCount` from `GET /api/notifications`, refetched by `unreadCountProvider` (`lib/state/notification_providers.dart:7-13`, `notifications_repository.dart:6-7`, `40-41`). The app does not add or subtract locally (`README.md:16`, `notification_models.dart:39`, `45-46`). Null `unreadCount` hides the badge; `0` is a real count.

### Notification HTTP contract the client actually calls

| Method and path | Client | Body |
|---|---|---|
| `GET /api/notifications` | `RemoteNotificationsRepository.list` (`notifications_repository.dart:25-28`). Optional query `before`. Null and empty queries are stripped (`dio_api_client.dart:141-144`). The screen's provider calls `list()` with no cursor, so it loads the first page only (`lib/state/section_providers.dart:193-196`). | — |
| `PATCH /api/notifications/{id}/read` | `markRead` (`notifications_repository.dart:31-33`, path at `api_endpoints.dart:113`) | Empty. No `requestId`. |
| `POST /api/notifications/read-all` | `markAllRead` (`notifications_repository.dart:36-38`, `api_endpoints.dart:114`) | Empty. No `requestId`. |
| `GET` and `PATCH /api/notification-preferences` | `preferences` / `updatePreferences` (`notifications_repository.dart:44-50`). The account screen reads `soundEnabled` and `speechEnabled` (`lib/features/settings/account_screen.dart:152-169`). | The patch body is the map the screen sends. |

`GET` does not send `X-CSRF-Token`. `PATCH` and `POST` do, when the in-memory token exists (`docs/session-behaviour.md:13-15`). The CSRF token is not stored (`docs/session-behaviour.md:7-9`). The session cookie is stored in `flutter_secure_storage` (`packages/api_layer/lib/core/auth/cookie_store.dart:6-8`, `34-42`).

List item fields the DTO reads (`notification_models.dart:4-36`):

| JSON key | DTO |
|---|---|
| `id` | `id` (string; numbers are stringified) |
| `action`, else `type` | `action` |
| `title`, `body` | optional strings |
| `section` | optional string |
| `entityId`, else `aggregateId` | `entityId` |
| `readAt`, `createdAt` | optional `DateTime` via `DateTime.tryParse` (`common.dart:22`) |
| `unreadCount` on the page | `int` or numeric string (`common.dart:42-43`); otherwise null |
| `nextBefore`, else `nextCursor` | `nextBefore` |

The comment at `notification_models.dart:4-6` says the web client builds text from `action` + `details`, and this app never renders numbers from `details`. `details` is not a DTO field. If `title` is missing, the screen uses a fixed Arabic label for a few `action` strings and «إشعار» otherwise (`lib/ui/presentation.dart:253-259`, `notifications_screen.dart:142-145`).

Known labels: `collection.submit`, `collection.approve` / `collection.approved`, `collection.reject` / `collection.rejected`, `collection.cash_received`.

Navigation uses `section` + `entityId`, and only when `section` matches a `SectionKey` (`lib/ui/section_labels.dart:46-65`). Keys include `collections`, `customers`, `companies`, `libyan-deposits`, `egyptian-deposits`, `masraweya`, `purchases`, `treasury`, `reports` (`permission_codes.dart:36-54`). Card sections append the entity id. There is no `relatedRef` object.

Fake fixture item (`packages/api_layer/lib/data/fake/fake_fixtures.dart:1054-1080`): `id` `"77"` / `"88"`, `action` `collection.submit`, `title`, `body`, `section` `collections`, `entityId`, `readAt`, `createdAt`, and on the second item `recipientUserId`. The comment on that last key says it is not a confirmed notifications field (`fake_fixtures.dart:1075`). The fake drops another user's row unless the caller is full-access (`fake_api_client.dart:1882-1893`). The DTO never reads `recipientUserId`, so the real client cannot apply that filter itself.

Logout and account switch invalidate `notificationsProvider`, `notificationPrefsProvider`, and `unreadCountProvider` (`lib/state/user_scope.dart:38-40`, `46-60`). Session cleanup also stops realtime, resets the sequence cursor, and calls `push.deleteToken()` (`api_layer.dart:152-158`).

## (c) Background fallback if push stays unavailable

This section is a recommendation for a later change. This PR does not add it.

Today, once the process is paused, hidden, or dead, nothing delivers. SSE and the 4-second timer are the only transports, and both are stopped by `RealtimeLifecycle`. There is no scheduled work, no boot receiver, and no local-notification plugin.

### Recommended fallback

Periodic polling with Android WorkManager, one unique periodic job per signed-in install:

1. **Minimum interval 15 minutes.** Android's `PeriodicWorkRequest` floor is 15 minutes (`PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS`). **Inferred from the Android platform, not from this repo.** The foreground 4-second interval (`api_config.dart:55`) must not be copied into the background job. WorkManager may defer the job further under Doze and App Standby. That deferral is the battery policy. Do not add a foreground service, an exact alarm, or expedited work for this poll.
2. **One GET, with the existing cookie.** `GET /api/notifications` through the same cookie jar (`SecureCookieStore`). `GET` does not send CSRF (`docs/session-behaviour.md:13-15`). Do not `PATCH` or `POST` from the worker: those need the in-memory CSRF token, which is gone after the process dies (`docs/session-behaviour.md:7-9`).
3. **Session failure stops the job.** On `401` or `419`, cancel the periodic work and show nothing. Leave the cookie wipe to the foreground `SessionManager`, which already treats an authenticated `401` / non-CSRF `419` as logout (`docs/session-behaviour.md:17-31`). **Inferred:** clearing the jar from the worker can race a request the UI still has in flight.
4. **No sensitive fields in the local notification or in the stored cursor.** Persist only the last `unreadCount` integer and, if needed, the unread item `id` strings. Do not persist `title`, `body`, `details`, names, phones, or amounts. The notification text is a fixed app string (the same class as the unknown-action label «إشعار» in `presentation.dart:258`). Question 18 is still open on whether `title` / `body` / `details` contain those values. Until that is answered, the worker must not copy them onto the shade. Do not put the cookie or the CSRF token in the notification.
5. **Notify only when the unread count goes up** (or an unread `id` appears that was not in the stored set). A repeated poll of the same count stays quiet.
6. **Android 13+ posting requires `POST_NOTIFICATIONS`.** The manifest does not declare it (`AndroidManifest.xml:2-3`). **Inferred platform requirement.** Ask at runtime before the first local notification.
7. **Cancel the job** on logout and when the signed-in user id changes, beside the existing `invalidateUserScope` (`user_scope.dart:53-60`).

`workmanager` is not a dependency (`pubspec.yaml:9-18`). Adding it is a later step.

### What "app killed" can actually do

| Situation | Delivery |
|---|---|
| Process alive, app foreground | SSE, or polling every 4 seconds while SSE is down. Signal only, then refetch. |
| Process alive, app backgrounded | Stopped by `RealtimeLifecycle` (`paused` / `hidden` / `detached`). Nothing until the app is in front again. |
| Process killed, current code | Nothing. No component restarts the stream. The cookie can still be in secure storage; nothing reads it until the next launch. |
| Process killed, WorkManager added, no FCM | Best-effort and late. The platform floor is 15 minutes, and Doze, App Standby, and OEM battery limits often make it longer. **Inferred:** after the user force-stops the app, Android does not run the job until the user opens the app again. **Inferred:** the Keystore-backed cookie (`cookie_store.dart:37-38`) may be unreadable before the first unlock after reboot; this repo does not set an unlock flag. If the server has already expired the cookie, the GET returns `401` and the job must stop. Session lifetime is unknown (question 42 in `docs/session-behaviour.md:5`). |
| Process killed, event should arrive immediately | Not possible with the transports this client has. That needs a device push channel. Question 19 is the question that decides it. |
| iOS, this repo | No `ios/` tree and no APNs client. Killed-app delivery on iOS is outside this repository. |

Web push, if the comment in `push_service.dart:1-2` is later confirmed, still would not wake this native process. A service worker is not part of this app.

## (d) Senior contract compared with this client

The senior engineer's draft (his PR, not this one) is proposed, not server-confirmed. His names: `AppNotification`, `NotificationsController.ingest` / `ingestOne`, `NotificationSource` (`push`, `poll`, `fetch`), `notificationsProvider`, `unreadNotificationsCountProvider`.

### Endpoints

| His proposal | On `main` | Status |
|---|---|---|
| `GET /api/notifications` | Called. Query `before`. Page is `items`, `unreadCount`, `nextBefore` (also accepts `nextCursor`). See section b. | Confirmed path. Response shape differs from `AppNotification` (fields table). |
| `GET /api/notifications/unread-count` | Constant `proposedUnreadCount` only (`api_endpoints.dart:117-118`). Repository comment says no dedicated endpoint and reads `unreadCount` from the first page (`notifications_repository.dart:13-15`, `40-41`). Question 17. The fake does not implement a count resource: the segment `unread-count` is skipped by the id check (`fake_api_client.dart:586`) and `GET` still returns the list page (`fake_api_client.dart:1075-1079`). | Differs. Not called. Treated as not implemented. |
| `POST /api/notifications/{id}/read` | `PATCH /api/notifications/{id}/read` with an empty body and no `requestId` (`notifications_repository.dart:31-33`). Matrix agrees on PATCH (`permission-enforcement-matrix.md:116`). | Differs (method and body). |
| `POST /api/notifications/read-all`, `requestId` idempotent | `POST /api/notifications/read-all` with an empty body (`notifications_repository.dart:36-38`). `MutationMeta` / `requestId` is how business writes dedupe (`idempotency.dart:1-9`) and this call does not use it. Fake notification writes skip the idempotent mutator (`fake_api_client.dart:857-871`). | Method matches. Idempotency differs. Whether the server wants `requestId` is unknown. |
| Status precedence `401` then `404` then `403` | The client maps the single status it received. An authenticated `401` becomes session expiry and logout (`error_mapper.dart:129-140`). `403` and `404` are separate types (`error_mapper.dart:182-195`). Matrix: own notifications, `404` for another user's id, no `403` (`permission-enforcement-matrix.md:115-117`). Fake: session `401` first (`fake_api_client.dart:835`, `874-881`), then `404` for another user's id (`fake_api_client.dart:582-590`). No `403` on this resource. | `401` then `404` matches the fake and the matrix for the cases they implement. A `403` on these routes is unknown. The client does not try a second status. An authenticated `401` logs the user out; ingest should not treat it as a per-item miss. |

`GET` / `PATCH /api/notification-preferences` is a live client path (section b) and is outside his model. PR #5 left it out of the gap list on purpose. The boolean names are what the screen reads; the live JSON is unknown beyond that.

### Fields

| His field | On `main` | Status |
|---|---|---|
| `notificationId` (stable string) | Item key is `id`. Nothing reads `notificationId`. | Differs (name). Whether the server also sends `notificationId` is unknown. |
| `recipientUserId` | Not on `NotificationDto`. Fake fixture only, comment says unconfirmed (`fake_fixtures.dart:1075-1076`). Fake filters before the response (`fake_api_client.dart:1882-1893`). | Unknown on the real server. |
| `systemName` | Absent from the notification model and fixture. | Unknown. |
| `employeeName?` | Absent from the notification model and fixture. | Unknown. |
| `operationType` enum, plus unknown | Free string `action`, with `type` as a fallback key (`notification_models.dart:29`). Not an enum. Unknown strings stay stored and display as «إشعار». | Differs. |
| `relatedRef { type: collection \| receipt \| account \| unknown, id }` | Flat `section` + `entityId` (fallback key `aggregateId`). Navigation matches `section` to `SectionKey` (`section_labels.dart:46-65`). No `receipt` or `account` type. Fake `section` is `collections`. | Differs. |
| `createdAt`, `readAt?` | Same names. `isRead` means `readAt != null` (`notification_models.dart:25`). | Confirmed as the keys the client parses. Wire format on the live server is still the ISO strings the parser accepts (`common.dart:22`). |
| `fromPushPayload(Map<String, dynamic>)`, flat map of strings | No such factory. `PushMessage` is `type` and `entityId` only, and no message is ever emitted. | Differs. No push map exists to be tolerant of. |
| `title`, `body`, and the comment's `details` | `title` and `body` are parsed. `details` is not. Question 18. | His model omits them. The client depends on `title` when it is present. |

### Transport and providers

| His rule | On `main` | Status |
|---|---|---|
| `ingest(List<AppNotification>, {required NotificationSource source})` and `ingestOne`. Sources `push`, `poll`, `fetch`. | No `NotificationsController`. Realtime and push listeners ignore the payload and invalidate providers (`realtime_lifecycle.dart:63-72`). | Differs. Nothing ingests a notification object from SSE, polling, or push. |
| Final dedup by `notificationId`, and drop `recipientUserId != current user`, inside ingest. Transport dedup is extra. | Transport dedup is the integer sequence (section b). The list is whatever `GET /api/notifications` returned. The client cannot drop on `recipientUserId` because it does not parse it. | Differs. His ingest rule has no input field to dedup on today. |
| Unread count refetched after each push, never incremented locally. | Matches the badge rule and the push listener (`realtime_lifecycle.dart:70-72`, `notification_providers.dart:7-13`, `README.md:16`). The push stream is empty, so the listener never runs. A realtime signal also refetches home, collections, and the open ledger, and does not refetch `notificationsProvider`. | The refetch rule matches. The provider name and the set of invalidated providers differ. |
| `notificationsProvider` | Exists as `FutureProvider<NotificationsPage>` that GETs the first page (`section_providers.dart:193-196`). It is not an ingest cache. | Name matches. Type and source differ. |
| `unreadNotificationsCountProvider` | The provider is `unreadCountProvider` (`notification_providers.dart:9`). | Differs (name). |
| Logout and account switch clear the cache and the count. | `invalidateUserScope` drops `notificationsProvider` and `unreadCountProvider` (`user_scope.dart:38-40`, `53-60`). Realtime cursor resets. `deleteToken` is a no-op. | Matches for the providers that exist. There is no local `AppNotification` cache and no tray notification to clear. |

### Mismatches to forward

1. Mark-read on `main` is `PATCH /api/notifications/{id}/read` with an empty body. His contract says `POST`. The matrix documents PATCH. The fake accepts any non-GET and does not prove the verb.
2. Read-all is `POST` with no body and no `requestId`. His contract says `requestId` and idempotent replay. This call does not use `MutationMeta`. The fake skips idempotency for notification writes.
3. `GET /api/notifications/unread-count` is proposed and uncalled. The count is `unreadCount` on `GET /api/notifications`. Question 17. His provider name `unreadNotificationsCountProvider` is `unreadCountProvider` here.
4. The stable id field the client reads is `id`, not `notificationId`. Realtime dedup is a numeric `sequence` / SSE `id:` line, not that string.
5. `recipientUserId` is not parsed. It appears only in the fake fixture, marked unconfirmed. If ingest drops every row where `recipientUserId != currentUser`, a missing field (the only shape this DTO knows) drops every row. **Inferred risk in his rule:** treat a missing `recipientUserId` as "server already scoped the list", and drop only when the field is present and different. The fake keeps a row when the field is absent, when it equals the caller, or when the caller is full-access; it removes a row only when the field names someone else and the caller is not full-access (`fake_api_client.dart:1882-1893`). A full-access caller therefore still receives the other user's row with `recipientUserId` set. The DTO then discards the field, so the UI cannot apply the same check.
6. `operationType` does not match `action` / `type`. There is no enum. Adding one will hide server values the string field currently keeps. The display fallback for an unknown `action` is «إشعار» (`presentation.dart:258`).
7. `relatedRef.type` of `collection | receipt | account | unknown` does not match `section` + `entityId`. The section strings the router understands are the `SectionKey` values (`customers`, `collections`, `companies`, `libyan-deposits`, `egyptian-deposits`, `masraweya`, `purchases`, `treasury`, `reports`). `receipt` and `account` are not among them. `aggregateId` is the alternate key for `entityId`, and it is also the realtime field, which is a record id, not a notification id.
8. `systemName` and `employeeName` are not in the notification JSON this client parses or fakes. Shipping the UI on them will show empty until the server sends them.
9. `fromPushPayload` has no source. `NoopPushService.messages` is empty. `PushMessage` is `{type, entityId}` and is ignored except as a cue to refetch `unreadCount`. There is no flat string map.
10. Do not dedup foreground SSE/polling by `notificationId`. Those payloads do not carry one. The existing dedup key is `sequence`. A resync (`full_resync_required`, reconnect, or a non-positive SSE id) is intentionally not deduped (`resilient_realtime_service.dart:44-47`, `sse_realtime_service.dart:141-150`).
11. `ingest` from a push or a poll is not how the screen updates. The list provider refetches only when something invalidates it (opening it, mark-read, mark-all, logout, account switch). A realtime signal does not invalidate `notificationsProvider` (`realtime_lifecycle.dart:63-68`).
12. Authenticated `401` on these routes is logout, not an ingest miss. Another user's notification id is documented as `404`, not `403` (`permission-enforcement-matrix.md:116`).
13. His model does not mention `title`, `body`, or `details`. The screen prefers `title` and refuses to render `details` (`notification_models.dart:4-6`). Dropping `title` changes the text users see once the server sends it (question 18).
14. His model does not mention `GET`/`PATCH /api/notification-preferences` (`soundEnabled`, `speechEnabled`). That screen is already on `main`.
15. Pagination: his model has no `before` / `nextBefore`. The DTO has `nextBefore`, and the provider never sends `before`, so the screen shows the first page only.

## (e) Questions for Ali

Questions 17, 18, and 19 stay as written in PR #5. They are not repeated. 41 (cookie flags), 42 (session lifetime), and 44 (WebView versus an app cookie jar) also stay as written; two questions below only add the background-GET case.

1. Following 19: if any `/api/browser-push/*` route exists, what is the method, the path, the request body, and the keys of a delivered message? Can any of those routes address an Android process, or only a browser service worker? If the route family does not exist, say so.
2. Is mark-read `PATCH /api/notifications/{id}/read` with an empty body (what this client sends), or `POST`, and does that call take a body?
3. Does `POST /api/notifications/read-all` require `requestId`, and does a second call with the same `requestId` stay a no-op? This client sends `POST` with no body.
4. On `GET /api/events` and `GET /api/event-changes`, is the cursor the numeric SSE `id:` / JSON `sequence` this client already dedups on? Does any event include a notification id (`id` or `notificationId`)? Which keys are inside `payload`? The client drops `payload`.
5. On `GET /api/notifications` items, is the stable id the field `id`? Is a separate `notificationId` ever sent?
6. Does a notification item include `recipientUserId`, and does the server already omit other users' rows for a normal session? The field is not parsed. The fake has it and filters; the fixture comment marks it unconfirmed.
7. Which `action` strings does the server emit? This UI has labels only for `collection.submit`, `collection.approve`, `collection.approved`, `collection.reject`, `collection.rejected`, and `collection.cash_received`. Every other string is shown as «إشعار».
8. Following 18: can `title`, `body`, or `details` contain a customer name, a phone number, or an amount? This client does not render `details`. A later Android local notification will not copy those fields if they can carry that data.
9. Following 41 and 44: will `GET /api/notifications` and `GET /api/event-changes` accept the login session cookie from a background Android process that sends no `Origin`, no WebView, and no `X-CSRF-Token`? This client does not send CSRF on `GET`, and the CSRF token is memory-only, so it is absent after the process is killed.
10. Are `soundEnabled` and `speechEnabled` the live booleans on `GET` and `PATCH /api/notification-preferences`? The account screen reads those two. The path is not in the proposed group. The body shape is not one of questions 1–52.
11. For `PATCH /api/notifications/{id}/read` on another user's id, is the status `404` (what the matrix and the fake do) or `403`? This client maps the status that arrived. An authenticated `401` logs the user out.
12. For the notification list, is the page query `before` and the next field `nextBefore`? The parser also accepts `nextCursor`. The screen currently requests the first page only.
