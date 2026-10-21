# Permission enforcement matrix

The server is the security boundary. Hiding a button is not enforcement. This matrix is what the server must do for every route the app calls. Client gating is listed so a mismatch is visible.

Session rules are in [session-behaviour.md](session-behaviour.md). The employee-totals shape, the source switch from open [PR #34](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/34), and the addendum to PR #5's question list are in [employee-totals-proposal.md](employee-totals-proposal.md). How to run the staging checks is in [staging-negative-tests.md](staging-negative-tests.md).

Paths come from `packages/api_layer/lib/core/network/api_endpoints.dart` and the repositories, the cookie strategy, and the realtime clients. `{section}` is `customers`, `companies`, `libyan-deposits`, or `egyptian-deposits`. `{book}` is `al_bayan` or `simsim`.

## Who is who

The server decides. The names below are the rules the app already uses for display, from `GET /api/me`.

| Name | Server signal the app trusts |
|---|---|
| Full management | `fullAccess: true`, or role `admin` with empty `permissions` and empty `sectionAccess`. Unknown roles grant nothing. |
| Limited manager | Role `admin` or `employee` with an explicit list. `collections.decide` is what the screen uses for totals and approve/reject today (DEF-002). The proposed totals route is stricter: full management only, until DEF-002 is decided. |
| Employee | Role `employee`. The fixture used in tests has `collections.read`, `collections.write`, `debts.read`, and `customerDebts: read`. Other sections are `none`. |
| Section read | Code `<section>.read` and `sectionAccess` not `none`. Collections is not in `sectionAccess`; the code alone is enough. |
| Section write | Section read, plus `<section>.write`, plus `sectionAccess: manage` when the section has an access key. Reports have no write. |
| Management action | Proposed code (`collections.assign`, `collections.decide`, `collections.cash_receive`, `collections.close_day`, `payroll.manage`, `debts.zero_review`, `users.manage`, `settings.manage`) or full management. These codes are unconfirmed. |

"Own data" means rows that belong to the signed-in employee: assignments assigned to them, submissions they created, their own payroll row, their own notifications. Customer and company cards are section data, not another employee's private totals. An employee with `debts.read` may see customer cards. They may not see another employee's totals, payroll, or submissions.

## 401, 403, and 404

Every disallowed response uses the normal error envelope and carries no other employee's name, phone, amount, or id in `error.details`.

1. **401** when the cookie is missing, logged out, or expired. Do this before any existence check. The same status and a generic message for every route. Login's 401 is bad credentials, not this rule. See [session-behaviour.md](session-behaviour.md).
2. **404** when the URL names a resource id (card, ledger line, submission, assignment, unlinked receipt, payroll employee, notification) that is outside the caller's visible set **or** does not exist. Use the same body either way. 403 on a foreign id tells the caller the id exists. This is the rule for "another employee's resource ids".
3. **403** when the id is inside the caller's visible set but the action is not allowed (an employee deciding their own submission), or when the route is a management capability and contains no foreign id (`POST /api/collections/days/close`, `GET /api/financial-ledger`, `GET /api/admin/employee-totals`, `POST /api/collections/assignments`).
4. `GET /api/admin/employee-totals` is **403** for an employee, not 404. Existence of that route is not a secret.

Order the server must apply: 401, then 404 for an id outside scope, then 403 for an action the caller cannot perform.

## Accounts

Client: list, ledger, and suggestions are shown only when `canRead` is true. Create, edit, movement, cancel, correction, and pin are shown only when `canWrite` is true and the card is not `systemManaged`. Zero-review is shown only for `debts.zero_review`. A direct link to a section the user cannot read redirects home. The repository still sends the request if something calls it. Match, as long as the server answers 403.

| Method | Path | Permission | Scope | 401 | 403 | 404 |
|---|---|---|---|---|---|---|
| GET | `/api/{section}` | Section read | Cards in that section. Not "own cards" unless the server's product rule says so. Do not include other sections. | Yes | No read | Unknown section |
| GET | `/api/{section}/suggestions?q=` | Section read | Same section | Yes | No read | Unknown section |
| POST | `/api/{section}` | Section write | Creates in that section | Yes | No write | Unknown section |
| GET | `/api/{section}/{id}` | Section read | That card if it is in scope | Yes | — | Unknown id, or id outside scope |
| PATCH | `/api/{section}/{id}` | Section write | That card | Yes | No write, or `systemManaged` | Id outside scope |
| GET | `/api/{section}/{id}/ledger` | Section read | That card's lines | Yes | No read | Id outside scope |
| POST | `/api/{section}/{id}/transactions` | Section write | That card. Body has `requestId` and `expectedVersion` | Yes | No write, or `systemManaged` | Id outside scope |
| POST | `/api/{section}/{id}/transactions/{tx}/corrections` | Section write | That line | Yes | No write | Card or line outside scope |
| POST | `/api/{section}/{id}/transactions/{tx}/cancel` | Section write | That line | Yes | No write | Card or line outside scope |
| PATCH | `/api/{section}/{id}/pin` | Section write | That card | Yes | No write | Id outside scope |
| POST | `/api/customers/{id}/zero-review` | `debts.zero_review` or full management | That customer. `expectedFinancialVersion` | Yes | Employee, or no code | Id outside scope |
| GET | `/api/egyptian-deposits/exchange-rate` | Egyptian deposits read | The one rate | Yes | No read | — |
| PATCH | `/api/egyptian-deposits/exchange-rate` | Egyptian deposits write | The one rate | Yes | No write | — |

Search calls `GET /api/{section}/suggestions` only for sections `canRead` allows. The server must 403 the others anyway.

## Collections

Client match: approve, reject, link, cash, close-day, and the totals block are built only when the matching management code is granted. The employee widget test expects those controls to be absent. The fake server returns 403 for decide, reject, cash, close, and assign when the employee calls them. That part matches.

Client diverge:

- The collections screen hides `employeeTotals` and the metrics block unless `collections.decide` is granted, but `GET /api/collections` is still fetched whole. The fake returns `employeeTotals`, every submission, and every assignment to any reader. The server must omit `employeeTotals` for an employee and must return only that employee's assignments and submissions. A limited manager with `collections.decide` still sees that block (DEF-002). That gate is wider than PR #34.
- Open [PR #34](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/34) is the totals client. It is not merged here. `--dart-define=EMPLOYEE_TOTALS_SOURCE=standalone` (the default) calls `GET /api/admin/employee-totals` and sends optional `from` and `to`. `collections` reads `employeeTotals` on `GET /api/collections` and does not send `from` or `to`. A profile that is not a full admin always uses the standalone path, so the server returns 403 and the collections array is not a substitute. PR #34 adds `cashOutstandingUnits` on each standalone item and treats a missing `currency` as `LYD`. `canViewEmployeeTotals` is full access only. This branch does not duplicate that repository.
- The payroll heading says "مرتبي" for an employee, and the widget prints every row the server sends. The fake sends every employee. The server must return only the caller's payroll row unless the caller has `payroll.manage` or full management.
- The fake checks the action before the id, so an employee decision on any id is 403. Prefer 404 when the id is not in the employee's scope, and 403 only when it is their own submission.

| Method | Path | Permission | Scope | 401 | 403 | 404 |
|---|---|---|---|---|---|---|
| GET | `/api/collections` | `collections.read` | Employee: own assignments, own submissions, own unlinked receipts. No `employeeTotals`. No other employee's name. Full management: all rows. `employeeTotals` on this payload is one of the two sources in PR #34 (`EMPLOYEE_TOTALS_SOURCE=collections`). Whether that array is authoritative, and which fields it carries, is the addendum in the totals proposal. | Yes | No read | — |
| GET | `/api/collections/assignees` | `collections.assign` or full management | Staff who can receive assignments | Yes | Employee | — |
| POST | `/api/collections/assignments` | `collections.assign` or full management | Creates assignments. No foreign-id disclosure. | Yes | Employee | Unknown customer id inside the body is 404 for that id |
| POST | `/api/collections/assignments/{id}/submissions` | `collections.write` | The assignment assigned to this employee | Yes | No write | Another employee's assignment id |
| POST | `/api/collections/submissions/{id}/decision` | `collections.decide` or full management | A submission the caller is allowed to see | Yes | Own submission, no decide | Another employee's submission |
| POST | `/api/collections/submissions/{id}/cash-received` | `collections.cash_receive` or full management | Same | Yes | Own submission, no cash permission | Another employee's submission |
| POST | `/api/collections/unlinked-receipts` | `collections.write` | The caller's own receipt | Yes | No write | — |
| GET | `/api/collections/link-candidates?q=` | `collections.decide` or full management | Cards the manager may link | Yes | Employee | — |
| POST | `/api/collections/unlinked-receipts/{id}/decision` | `collections.decide` or full management | A receipt the caller may see | Yes | Own receipt, no decide | Another employee's receipt |
| POST | `/api/collections/unlinked-receipts/{id}/cash-received` | `collections.cash_receive` or full management | Same | Yes | Own receipt, no cash permission | Another employee's receipt |
| POST | `/api/collections/days/close` | `collections.close_day` or full management | The open batch. No employee id in the path. | Yes | Employee | Unknown `batchId` in the body |
| GET | `/api/collections/payroll` | `collections.write` sees own row. `payroll.manage` or full management sees all. | Own row, or all | Yes | No collections read | — |
| POST | `/api/collections/payroll/entries` | `payroll.manage` or full management | Any employee in the body | Yes | Employee, including confirm of someone else's row | Unknown `employeeUserId` |
| PUT | `/api/collections/payroll/employees/{employeeId}/salary` | `payroll.manage` or full management | That employee | Yes | Employee | Another employee's id, or unknown id |
| POST | `/api/collections/payroll/entries/{entryId}/confirm` | Own entry: `collections.write`. Any entry: `payroll.manage` or full management | That entry | Yes | Someone else's entry without manage | Another employee's entry id |

`GET /api/admin/employee-totals` is the standalone source, and the default in [PR #34](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/34). Rules: [employee-totals-proposal.md](employee-totals-proposal.md). Employee 403. Limited manager 403 until DEF-002. Full management 200. No session 401. No `employeeId` query. Optional `from` and `to` (`YYYY-MM-DD`) apply to this path. The collections screen on this branch does not call it.

## Masraweya, purchases, treasury, reports

Client: each screen is mounted only when `canRead` is true. Writes are hidden unless `canWrite` is true. Purchase finalize is hidden unless `purchases.finalize` and purchases write are both true. Reports have no write control. The financial ledger and PDF export are shown only for full management, and PDF only in fake mode. Match, if the server 403s.

| Method | Path | Permission | Scope | 401 | 403 | 404 |
|---|---|---|---|---|---|---|
| GET | `/api/masraweya/day` | Masraweya read | The requested date, or the server's current day | Yes | No read | — |
| PUT | `/api/masraweya/day` | Masraweya write | That day. `requestId` + `expectedVersion` | Yes | No write | — |
| GET | `/api/purchases/{book}` | Purchases read | That book | Yes | No read | Unknown book |
| POST | `/api/purchases/{book}` | Purchases write | That book, editable day | Yes | No write, or finalized day | Unknown book |
| PATCH | `/api/purchases/{book}/entries/{id}` | Purchases write | That entry | Yes | No write, or finalized day | Entry outside the book |
| DELETE | `/api/purchases/{book}/entries/{id}` | Purchases write | That entry | Yes | No write, or finalized day | Entry outside the book |
| PATCH | `/api/purchases/{book}/opening` | Purchases write | That book | Yes | No write | Unknown book |
| POST | `/api/purchases/{book}/finalize` | `purchases.finalize` and purchases write, or full management | That book | Yes | No finalize | Unknown book |
| PATCH | `/api/purchases/{book}/days/{day}/correction` | `purchases.finalize` and purchases write, or full management | That day | Yes | No finalize | Unknown day |
| GET | `/api/treasury` | Treasury read | The treasury summary | Yes | No read | — |
| GET | `/api/treasury/cash-ledger` | Treasury read | Cash lines | Yes | No read | — |
| POST | `/api/treasury/cash-entries` | Treasury write | New cash line | Yes | No write | — |
| GET | `/api/reports` | Reports read | Report rows | Yes | No read | — |
| GET | `/api/financial-ledger` | Full management only. No permission code opens it. | All sections the ledger contains | Yes | Employee and limited manager | — |
| GET | `/api/statements/pdf` | Full management, and only if the server adds it. The app calls it in fake mode. | The requested section or card | Yes | Not full management | Route not deployed, or id outside scope |

## Home, notifications, realtime

| Method | Path | Permission | Scope | 401 | 403 | 404 |
|---|---|---|---|---|---|---|
| GET | `/api/home` | Any signed-in user. Proposed route. | Drop summaries, counters, and debt rows for sections this user cannot read. The fake already does this. | Yes | — | Route not deployed. The app then reads each section it may read. |
| GET | `/api/notifications` | Any signed-in user | Own notifications and own `unreadCount` | Yes | — | — |
| PATCH | `/api/notifications/{id}/read` | Any signed-in user | Own notification | Yes | — | Another user's notification id |
| POST | `/api/notifications/read-all` | Any signed-in user | Own notifications | Yes | — | — |
| GET | `/api/notification-preferences` | Any signed-in user | Own preferences | Yes | — | — |
| PATCH | `/api/notification-preferences` | Any signed-in user | Own preferences | Yes | — | — |
| GET | `/api/events` | Any signed-in user | Events for records in scope. 401/419 stops the client. | Yes | — | — |
| GET | `/api/event-changes` | Any signed-in user | Same scope as SSE | Yes | — | — |
| GET | `/api/me` | The session cookie | That user only | Yes | — | — |

## Auth routes

| Method | Path | Permission | 401 | Notes |
|---|---|---|---|---|
| POST | `/api/auth/login` | Public | Bad credentials, not session expiry | Sets the cookie. Returns `csrfToken`. |
| GET | `/api/auth/csrf` | Session cookie | Expired or missing cookie | Body `{ok:true, data:{csrfToken}}`. |
| POST | `/api/auth/logout` | Session + CSRF | Already dead | Server invalidates the cookie before the response. |
| POST | `/api/auth/change-password` | Session + CSRF | See session doc | Own password only. |

`POST /api/auth/mobile/*` is not called. Bearer mode is a stub.

## Declared and not called on this commit

These constants exist. No repository calls them yet. If a later build calls them, the server rule is already:

| Path | Rule |
|---|---|
| `GET /api/health`, `GET /api/setup/status` | Public. No session data in the body. |
| `GET /api/notifications/unread-count` | Own count. 401 without a session. |
| `POST /api/mobile-push/devices` | Own device. 401 without a session. |
| `GET /api/account-requests` | Full management, or `users.manage` if that code is confirmed. Employee 403. |
| `POST /api/account-requests/{id}/decision` | Same permission. 404 when the id is outside scope. `requestId` + `expectedVersion`. |

## Writes and idempotency

Every business write sends `requestId`. Versioned writes also send `expectedVersion`, `expectedDayVersion`, or `expectedFinancialVersion`. The client does not retry those methods on 502/503, and it does not retry them on 401/419. A manual retry of the same form reuses `requestId`. See [session-behaviour.md](session-behaviour.md).
