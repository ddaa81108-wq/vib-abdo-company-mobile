# Push transport

Phase 6 step 2. This is the device-token and delivery path in front of the
notifications controller from PR #41. It does not change that model, the
repository, the providers, or the merge rules.

The server still has no mobile push. The default transport is a no-op.

## Architecture

```text
PushTransport (noop | fake | fcm stub)
        │  raw map
        ▼
whitelist (allowed keys only)
        ▼
AppNotification.fromPushPayload
        ▼
current-user filter, then NotificationIdDedup
        ▼
NotificationsController.ingest / ingestOne
```

SSE and polling do not enter that pipe. A realtime signal calls
`refresh(announce: true)` after a short coalesce. The event payload is not
read. The first connect resync is skipped so the controller's own initial
load stays `announce: false`.

| Piece | Role |
|---|---|
| `PushTransport` | `NoopPushTransport` (default), `FakePushTransport` (tests), `FcmPushTransport` (stub). Chosen by `pushTransportProvider`. |
| `NotificationIngress` | Whitelist, fail-closed recipient check, shared LRU, then his `ingest`. |
| `DeviceTokenRegistrar` | Register after login. `forget` on logout, account switch, and the session wipe. |
| `PushSessionGate` | The wipe from PR #38 calls `forget`. A thrown unregister cannot fail logout. |
| `NotificationPermissionService` | Abstract. The stub reports not granted. The UI dev owns the real check and `POST_NOTIFICATIONS`. |
| `BackgroundNotificationPoll` | `GET /api/notifications` when the flag is on. Generic shade text only. |
| `NotificationOpener` | `open(AppNotification, {required NotificationOpenOrigin origin})`. |

The device token lives in `SecureDeviceTokenStore` (`push.device_token.v1`,
`flutter_secure_storage`). It is not written to logs. The redactor treats
`token`, `devicetoken`, and `pushtoken` as sensitive. Drop logs print counts
only.

The push whitelist is `notificationId`, `recipientUserId`, `operationType`,
`relatedRef` (`type` and `id` only), `relatedRefType`, `relatedRefId`,
`createdAt`, and `systemName`. `systemName` is kept because the shade line is
that name plus a fixed label. `employeeName`, title, body, amounts, phones,
and tokens are discarded before `fromPushPayload`.

## Flags

| Define | Default | Effect |
|---|---|---|
| `PUSH_TRANSPORT` | empty → noop | `fake` injects payloads in tests. `fcm` selects the stub, which returns no token. |
| `BACKGROUND_NOTIFICATION_POLL` | `false` | When true, an in-process scheduler may poll. It is not WorkManager. |

Both are `--dart-define` values. Tests read the defaults.

## What works in each app state

| State | Today (no server push) | After the server adds push |
|---|---|---|
| Open, signed in | SSE `GET /api/events`, or `GET /api/event-changes` every 4 seconds while SSE is down. Stop on pause, hidden, detached, `401`, and `419`. After the connect resync, a signal coalesces into `refresh(announce: true)`. | Same, plus `FakePushTransport` or a real FCM adapter calling `ingest` with `NotificationSource.push`. His ingest refetches the unread count. |
| Background, process alive | Realtime stops. The background flag is off, so nothing polls. | With the flag on, the in-process scheduler polls at 15 minutes or more, only while a user id is in memory. `401` / `419` cancels it. |
| Process killed | Nothing is delivered. There is no push token and no OS worker. | Still nothing until a real FCM adapter and WorkManager are linked. The stub and the in-process scheduler do not survive process death. |

A local line, when a poll shows one, is `systemName` plus a fixed operation
label (`VIB · اعتماد`). It does not include title, body, employee name, the
related id, an amount, a phone, or a token. Opening the row loads the detail
from the server.

## Device registration

🔶 `POST /api/mobile-push/devices` is the existing proposed constant. This
client calls it only when the transport is not `NoopPushTransport`, the
session is authenticated, `NotificationPermissionService.granted` is true,
and the transport returned a token.

The body is unconfirmed: `{token, platform: android}` to register, and the
same fields plus `unregister: true` to unregister. A failed call is ignored.
`forget` deletes the local token first.

The stub permission is not granted, and the FCM stub has no token, so a
normal launch does not call the endpoint.

## FCM

`firebase_messaging` is not a dependency. Adding it applies the Google
Services Gradle plugin, which fails the Android build without
`google-services.json`. That file, `GoogleService-Info.plist`, and
`firebase_options.dart` are gitignored and must not be committed.
`FcmPushTransport` is the seam those plugins would implement. It yields no
token and no messages.

## Background poll and WorkManager

`workmanager` is not a dependency. A worker that posts a shade notification
would pull in a plugin whose manifest merger adds `POST_NOTIFICATIONS`, and
that permission belongs to the UI dev.

`NoopBackgroundNotificationScheduler` is what runs by default.
`InProcessBackgroundNotificationScheduler` is selected only when the flag is
on. Its period cannot be under 15 minutes. It does not run after the process
dies. `InProcessBackgroundNotificationScheduler.tick` is the function a later
WorkManager callback should call. Question 9 below has to be answered
before the flag is turned on: the cookie may not be accepted from a
background process that sends no `Origin` and no `X-CSRF-Token`.

## Dependencies and the manifest

`flutter_secure_storage` is now a direct app dependency. The API layer
already depended on it; the app imports it for `SecureDeviceTokenStore`.

Not added: `firebase_messaging`, `workmanager`, `flutter_local_notifications`,
`permission_handler`. No Android manifest change. `POST_NOTIFICATIONS` is
not declared.

## Tap handling

`notificationOpenerProvider` exposes `NotificationOpener`.

- No session, or a session that is not `SessionAuthenticated`: result
  `needsLogin`, destination kept in memory, no `markRead`. A cold start
  (`SessionUnknown`) does not leave `/splash`. After restore or login,
  `resumePending` runs the same `open`.
- `recipientUserId` must match on `banner` and `systemTray`. A missing id is
  `forbidden` for those origins. A list row may omit it, because his
  `fromDto` clears the field and list/poll rows are session-scoped.
- The role must `canRead` the target section
  (`docs/permission-enforcement-matrix.md`). Otherwise `/forbidden`.
- `collection` and `receipt` open `/collections`. A card section key opens
  `/{section}/{id}`. `account` with no book, or an unknown type, is
  `noTarget` and stays on `/notifications`.
- A card `GET` that returns `404` is `notFound`.
- `markRead` goes through his controller (and therefore his repository) only
  after the session and the recipient check. A thrown read does not stop
  navigation.

## Open questions

Questions 1–12 are in
[push-notifications-verification.md](push-notifications-verification.md)
(PR #40). They are not repeated here. Question 9 in that list is the one
that gates `BACKGROUND_NOTIFICATION_POLL`.

13. Does the standalone `GET /api/notifications/unread-count` route exist,
    and is the body `{unreadCount: int}`? His `refresh` calls
    `serverUnreadCount()` before it ingests the list. This transport calls
    `refresh(announce: true)` for a realtime signal. If that route 404s, the
    refresh throws and the list is left as it was. The initial load does not
    use the route. This is the same gap as question 7 in
    `docs/notifications-phase6-contract.md`.
