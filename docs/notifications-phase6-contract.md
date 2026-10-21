# Phase 6 — notifications data contract

This is the foundation for the notifications UI and for a separate push transport.
It does not register devices, request Android notification permission, map taps
to routes, or talk to FCM. `relatedRef` is the only navigation data on the model.

Confirmed facts are the ones already stated in
[permission-enforcement-matrix.md](permission-enforcement-matrix.md) and in the
current client (`NotificationsRepository`, `NotificationDto`). Everything else
is 🔶 proposed.

## Model `AppNotification`

| Dart field | Type | JSON |
|---|---|---|
| `notificationId` | `String` | Read `id` first (the field the current client sends and parses). Fall back to `notificationId`. |
| `systemName` | `String` | 🔶 `systemName`, else `system`. Missing → `''`. Never throws. |
| `employeeName` | `String?` | 🔶 `employeeName`. Missing → null. |
| `operationType` | `NotificationOperationType` | `operationType`, else confirmed `action`, else `type`. |
| `operationTypeRaw` | `String` | The original text, including unknown values. |
| `relatedRef` | `NotificationRelatedRef?` | Whole object is null unless both type and id are present. |
| `createdAt` | `DateTime` | Confirmed `createdAt`. Unparseable → Unix epoch. Never throws. |
| `readAt` | `DateTime?` | Confirmed `readAt`. Unparseable → null. |
| `recipientUserId` | `String?` | 🔶 Unconfirmed. Null when the key is missing. |
| `isRead` | `bool` | `readAt != null`. |

`NotificationOperationType` known wire values only:

- `collection.submit`
- `approve`
- `approved`
- `reject`
- `rejected`
- `cash_received`

Anything else, including an empty string, is `unknown`. The raw string is kept.
Parsing does not throw.

`NotificationRelatedRef` is `{type: String, id: String}`. `type` is free text
(`collection`, `receipt`, `account`, or any other string). There is no closed
enum. Sources, first match that has both parts:

1. 🔶 object `relatedRef: {type, id}` (a JSON string is accepted for push)
2. 🔶 flat `relatedRefType` + `relatedRefId` (push payloads are flat strings)
3. Confirmed `section` + `entityId` (or `aggregateId`)

Optional `title` and `body` are still parsed when present. The current screen
already shows them. They are not new server fields.

`AppNotification.fromJson` and `AppNotification.fromPushPayload` both tolerate
string-typed values. Push data is a flat map. Unknown keys are ignored.

## Endpoints

| Call | Status | Body |
|---|---|---|
| `GET /api/notifications` | Confirmed in the permission matrix. Any signed-in user. Own rows and own `unreadCount`. | Query `before` is 🔶 unconfirmed. Response may include `nextBefore` or `nextCursor`. Both are parsed. A payload with no pagination fields is valid. |
| `PATCH /api/notifications/{id}/read` | The current client already sends this. Not POST. | Empty body. No `requestId` on the wire. |
| `POST /api/notifications/read-all` | Confirmed in the permission matrix. The current client already sends this. | No body. No `requestId` on the wire. |
| `GET /api/notifications/unread-count` | 🔶 Proposed. The matrix lists it as declared and not called. The constant is `ApiEndpoints.proposedUnreadCount`. | 🔶 Response `{unreadCount: int}`. |

`requestId` acceptance is unknown. Other mutations in this repo put `requestId`
in the JSON body, not in a header, so this client does not invent a header.
The app keeps a stable `requestId` per in-flight action and replays the stored
result instead of calling again. The fake does the same when a caller supplies
`requestId` in the body (tests only; the repository does not send it). 🔶

Write responses are 🔶 proposed so the UI can apply the server count without a
local increment:

- mark one: `{unreadCount, readAt, notification}`
- mark all: `{unreadCount, readAt}`

If `unreadCount` is missing, the controller refetches
`GET /api/notifications/unread-count`. It never increments or decrements a
local counter as the source of truth.

Fake effects: marking one unread row decrements that user's server count by
one. Marking a row that is already read does not decrement again. Read-all
sets that user's count to 0. A replay of the same `requestId` returns the
stored result and does not apply the effect again.

## Permissions (fake)

Order, matching the rest of the fake:

1. **401** `AUTH_REQUIRED` when the session is missing or expired. This wins
   over 404, including when the path names another user's id.
2. **404** `NOT_FOUND` when `{id}` is not the caller's row, and when the id
   does not exist. Same body either way. 🔶 The matrix already says 404 for
   another user's id; server verification has not confirmed 404 vs 403.
3. **403** only for the existing rule that an employee id in the query is not
   how own notifications are read. There is no extra role ban on own
   notifications: any signed-in user may list and mark their own.

Each user sees only their own rows. Admin does not see another user's rows.
Fixtures: `u_12` (`77`), `u_20` (`88`, `n_20`), admin `u_1` (`n_1`).
`other.employee…` is a fake-only login for the existing id `u_20`.

A 401 from the real client stack still goes through `SessionManager.forceLogout`.

## Providers

`notificationsProvider` is
`AsyncNotifierProvider<NotificationsController, NotificationsPage>`.
The current screen keeps watching `AsyncValue<NotificationsPage>`.
Retry is `ref.invalidate(notificationsProvider)`.

`notificationsStateProvider` is `Provider<NotificationsState>`:

- `NotificationsLoading`
- `NotificationsEmpty`
- `NotificationsReady(List<AppNotification> items)`
- `NotificationsFailure(AppFailure failure)`
- `NotificationsForbidden` — `message` is `AppStrings.forbidden`. The server
  sentence is not stored.

`unreadNotificationsCountProvider` is `AsyncValue<int>` from
`GET /api/notifications/unread-count` only. Signed out, the value is `0` so
the previous account's count is gone. The existing `unreadCountProvider`
(`int?`, hidden when the list omits `unreadCount`) is unchanged for the bell.

`NotificationsController`:

- `ingest(List<AppNotification> items, {required NotificationSource source, bool announce = false})`
- `ingestOne(AppNotification item, {required NotificationSource source, bool announce = false})`
- `refresh({bool announce = false})` — `GET /api/notifications` and
  `GET /api/notifications/unread-count`, then `ingest(..., source: fetch)`.
  Realtime (SSE `/api/events` and polling `/api/event-changes`) should call
  `refresh(announce: true)`. This contract does not attach that call.
- `markRead(String notificationId)` and `markAllRead()` — update `readAt` on
  the cached rows and set the unread count from the server response. One
  stable `requestId` for the in-flight action. A failed attempt keeps the id.
  A finished attempt drops it. A second read of an already-read row does not
  decrement the server count again.

`NotificationSource` is `push`, `poll`, `fetch`.

Dedupe is by `notificationId`. The later `readAt` wins (`null` is earlier than
any timestamp). Order is `createdAt` descending, then `notificationId`
ascending.

Recipient filter:

- `fetch` and `poll`: keep a null `recipientUserId` (the server already bound
  the row to the session). Drop the row when the id is present and is not the
  current user.
- `push`: drop the row unless `recipientUserId` is present and equals the
  current user.

`foregroundNotificationsProvider` is `StreamProvider<AppNotification>`. It
emits a row only when it is newly seen, still unread, and either
`source == push` or `announce` is true. The initial list uses `announce: false`,
so it does not raise banners. A later poll of the same id does not emit again.
After a push ingest, the unread count is refetched. It is not incremented
locally.

Logout and account switch clear the list, the count, and the foreground
stream. `invalidateUserScope` drops `notificationsProvider`,
`unreadNotificationsCountProvider`, and `foregroundNotificationsProvider`.
The controller also watches `sessionStateProvider`, so a new account cannot
read the previous account's rows.

## Open questions for the backend

1. Confirm `PATCH /api/notifications/{id}/read` with an empty body, and
   `POST /api/notifications/read-all` with no body. This client will not send
   POST for a single id.
2. Does the server accept `requestId` on those two writes? This client does
   not send it until that is confirmed.
3. Is `recipientUserId` a real field? Push needs it. List/poll can omit it.
4. Is pagination `before` / `nextBefore` / `nextCursor`?
5. What is the push data payload (flat string keys, `relatedRef`, operation
   names)?
6. Is another user's notification id **404** or **403**? The fake uses 404 so
   the caller cannot learn that the id exists.
7. Is `GET /api/notifications/unread-count` deployed, and is the body
   `{unreadCount: int}`?
8. Do mark-read and mark-all responses include `unreadCount` (and the updated
   row / `readAt`)?
9. Are `systemName`, `employeeName`, `operationType`, and `relatedRef`
   server fields, or should the client keep using `action`, `section`, and
   `entityId` only?
