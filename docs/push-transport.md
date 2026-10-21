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

The transport whitelist is `notificationId`, `recipientUserId`,
`operationType`, `relatedRef` (`type` and `id` only), `relatedRefType`,
`relatedRefId`, `createdAt`, and `systemName`. It runs before
`fromPushPayload`, which has its own allow list and drops `systemName`.
`employeeName` stays off both lists. A push map is untrusted, and the name
is personal data: copying it from the payload could put it on a locked
screen before the server has confirmed the row. The tray reads the name
only from the `AppNotification` returned by `GET /api/notifications`
(after refresh). Title, body, amounts, phones, and tokens are discarded
by both layers as well.

## Flags

| Define | Default | Effect |
|---|---|---|
| `PUSH_TRANSPORT` | empty → noop | `fake` injects payloads in tests. `fcm` selects the stub, which returns no token. |
| `BACKGROUND_NOTIFICATION_POLL` | see below | When on, WorkManager polls. Release stays off until question 9. |

`BACKGROUND_NOTIFICATION_POLL` is a `--dart-define` string.

- Explicit `true` turns the poll on, including in a release build, once question 9 is answered.
- Explicit `false` turns it off, including in debug.
- Unset and release (`kReleaseMode`): off.
- Unset and debug (`kDebugMode`), or unset with `USE_FAKE_API=true` outside release: on.
- Production and release builds leave it unset, so the poll stays off.

`resolveBackgroundNotificationPoll` is the selector. The old const
`kBackgroundNotificationPoll` is still false unless the define is true.

## What works in each app state

True delivery while the app is closed is not supported until the server
offers push. WorkManager only polls `GET /api/notifications` on a schedule.
It is not a push channel.

| State | What runs |
|---|---|
| Open, signed in | SSE `GET /api/events`, or `GET /api/event-changes` every 4 seconds while SSE is down. Stop on pause, hidden, detached, `401`, and `419`. After the connect resync, a signal coalesces into `refresh(announce: true)`. A push, when the flag-selected transport delivers one, refreshes and then posts the server row to the system tray. |
| Background, process alive | Realtime stops. With the poll flag on, WorkManager runs the periodic GET. With the flag off, nothing polls. |
| Swiped away from Recents | WorkManager usually keeps the periodic work and reschedules it. That is the common case, not a promise. |
| Force-stopped | WorkManager stops. It stays stopped until the user opens the app again. |
| After reboot | WorkManager reschedules the periodic work when the process is allowed to start. Force-stop still blocks that until the next open. |

WorkManager limits, in production and in debug:

- 15 minutes is the floor Android accepts for periodic work. The real gap is often longer. It is not a guarantee.
- Doze defers runs.
- OEM battery savers (Xiaomi, Huawei, Samsung, and others) may delay or kill the worker.
- A swipe from Recents usually leaves the work registered. Force stop does not.
- The worker posts nothing while logged out. A `401` or `419` cancels the unique work and clears the worker's dedup and cursor. It does not clear the foreground cookie jar.

In production the flag stays off until question 9 is answered, so none of the rows above run the poll in a release build.

The private tray line is the system name as the title, and the fixed operation label plus the server employee name as the body when that name is present. The lock-screen public version is the system name plus `إشعار جديد`. Amounts, customer names, phones, and tokens are not copied. Tapping uses `NotificationOpener` with origin `systemTray`, including a cold start.

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

`WorkManagerBackgroundScheduler` is selected when the flag is on.
`NoopBackgroundNotificationScheduler` is selected when it is off.
`InProcessBackgroundNotificationScheduler` remains for tests. It does not
survive process death and it is not the production scheduler.

The periodic work uses unique name `vib.notification.poll`, an interval of
at least 15 minutes, a connected-network constraint, and
`ExistingPeriodicWorkPolicy.keep`. The worker isolate restores the cookie
from secure storage, calls `GET /api/me` and `GET /api/notifications`, drops
other users' rows, skips read rows and ids already shown, and posts through
the same tray poster. Fake mode has no persisted cookie, so the production
worker posts nothing there. Tests call `NotificationPollWorker.run` with an
injected session.

Question 9 still has to be answered before the flag is turned on in
production. The worker sends the cookie and does not send `X-CSRF-Token`
(the call is a GET) or an `Origin` header.

Logout, account switch, and the session-expiry wipe cancel that unique work
and clear the tray dedup plus the poll cursor. A `401` or `419` inside the
worker does the same cancel and clear, and leaves the foreground cookie
store alone so it does not race a UI request.

## System tray

`localNotificationPosterProvider` posts through
`AndroidNotificationController.showPrivateAlert` on channel
`vib_collections_alerts`. The activity method channel `app/system_tray`
sets `VISIBILITY_PRIVATE` and `setPublicVersion` (the Flutter plugin cannot).
The Android id is a stable hash of `notificationId`. The tag is
`notificationId`, so a repeat replaces the existing notification.

The same id is skipped when it is already in the transport LRU or the
persisted tray store, or the row is already read. Push and poll share that
dedup. The unread count stays the server's number; the same id is not added
twice.

A push waits for the refresh. If the signed-in user changed before the GET
finishes, nothing is posted. A failed GET posts no employee name. A `404`
posts nothing. A `401` posts nothing.

The list and the banner call `notificationOpenSeamProvider`, which delegates
to `NotificationOpener`. List taps use origin `list`. Tray taps use origin
`systemTray`.

## Dependencies, Gradle, and the manifest

Direct dependencies added for this tray and poll:

- `workmanager` ^0.10.10

Already present from earlier PRs, and reused: `flutter_local_notifications`
^22.3.2, `flutter_secure_storage` ^9.2.2, `permission_handler` 12.0.3,
`shared_preferences`. Not added: `firebase_messaging`.

App Gradle (`android/app/build.gradle.kts`):

- `implementation("androidx.core:core-ktx:1.15.0")` so `MainActivity` can
  call `NotificationCompat.setPublicVersion`.
- No other app Gradle change. `minSdk`, desugaring, and the optional
  Google Services plugin are unchanged.

`workmanager_android` 0.10.9 pulls `androidx.work:work-runtime:2.11.2` on
its own. That line is not in the app Gradle file.

App source manifest (`android/app/src/main/AndroidManifest.xml`): no edit.
`POST_NOTIFICATIONS` was already declared by the notification-channel change
and is reused. `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, and
`USE_EXACT_ALARM` are still absent from that file.

Plugin manifests that merge into the APK, and were not copied into the app
manifest:

- `workmanager_android` declares `POST_NOTIFICATIONS` (already on the app),
  `FOREGROUND_SERVICE`, and `FOREGROUND_SERVICE_SHORT_SERVICE`. This poll
  does not start a foreground service.
- `androidx.work:work-runtime` merges its reschedule receiver, which is what
  lets periodic work survive reboot. The app source does not declare
  `RECEIVE_BOOT_COMPLETED`.

## Tap handling

`notificationOpenerProvider` exposes `NotificationOpener`.

- No session, or a session that is not `SessionAuthenticated`: result
  `needsLogin`, destination kept in memory, no `markRead`. A cold start
  (`SessionUnknown`) does not leave `/splash`. After restore or login,
  `resumePending` runs the same `open`.
- `recipientUserId` must match on `banner` and `systemTray`. A missing id is
  `forbidden` for those origins. `fromDto` copies `recipientUserId` when the
  list row has it. A list row may still omit it; that origin stays openable
  because the list is session-scoped. A present mismatch is `forbidden`.
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
    and is the body `{unreadCount: int}`? `refresh` now fetches
    `GET /api/notifications` and ingests that list first, then fetches the
    unread count. A 404 or any other non-auth failure of the count route uses
    `unreadCount` from the list response. If the list omits that field too,
    the previous count stays. The list is not left stale, and a count failure
    does not roll it back. The initial load still does not call the count
    route. This is the same open question as question 7 in
    `docs/notifications-phase6-contract.md`.
