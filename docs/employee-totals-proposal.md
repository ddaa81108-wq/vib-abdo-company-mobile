# Employee totals — proposal, implemented in PR #34

Status: **unconfirmed server contract**. The client that reads this report is open [PR #34](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/34) (`cursor/admin-employee-totals-a4a3`). This branch does not add a second client and does not switch the collections screen over.

PR #34 chooses the source with `--dart-define=EMPLOYEE_TOTALS_SOURCE=`:

| Value | Request |
|---|---|
| `standalone` (default, and any value other than `collections`) | `GET /api/admin/employee-totals`. Optional `from` and `to` are sent when set. |
| `collections` | `GET /api/collections`, then the `employeeTotals` array (contract-gap item 14). `from` and `to` are not sent. |

`EmployeeTotalsRepository.fetch` is the only read. The provider does not branch. If the signed-in profile is not a full admin, PR #34 always calls the standalone path, even when the define says `collections`, so the server answers 403. The collections array is not returned in place of that denial.

## Shape PR #34 parses

```text
GET /api/admin/employee-totals?from=YYYY-MM-DD&to=YYYY-MM-DD
```

Both query parameters are optional. There is no `employeeId` query parameter.

```json
{
  "generatedAt": "2026-10-18T18:00:00+02:00",
  "from": null,
  "to": null,
  "version": 1,
  "currency": "LYD",
  "items": [
    {
      "employeeId": "u_12",
      "employeeName": "موظف استلام تجريبي",
      "collectedUnits": 0,
      "pendingUnits": 100,
      "approvedCount": 0,
      "rejectedCount": 0,
      "pendingCount": 1,
      "cashOutstandingUnits": 250,
      "currency": "LYD"
    }
  ],
  "totals": {
    "collectedUnits": 0,
    "pendingUnits": 100
  }
}
```

## Rules the client already applies

- `employeeName` falls back to `displayName` when `employeeName` is absent.
- `cashOutstandingUnits` is per employee. The parser does not copy `metrics` onto a row.
- `currency` on the report, and on an item when the server sends it. A missing or unknown code is read as `LYD`. `EGP` is accepted when the server sends it.
- Every `*Units` value must be a JSON integer. A string or a fraction is `INVALID_SERVER_RESPONSE`. The app does not scale and does not add the rows. `totals` is shown as sent. Null money is "not sent", not zero.
- Counts are not money.
- Full management only, until DEF-002 is decided: `PermissionService.canViewEmployeeTotals` is the same gate as full access. A limited manager is **403** even with `collections.decide`. An employee is **403** (the route's existence is not a secret). No session is **401** `AUTH_REQUIRED`. Passing `employeeId` does not narrow the call.
- On this branch the collections screen still paints `employeeTotals` when `collections.decide` is granted. That gate is wider than PR #34 (the limited-admin fixture has `collections.decide`). The screen has not moved to `employeeTotalsProvider`.

## Addendum to PR #5's list

`docs/api-contract-gaps.md` is not on `main`. It lives in open [PR #5](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/5) ("Document unconfirmed API contract gaps"). This section is an addendum to that list. It does not copy the list.

Employee totals, for the backend owner:

1. Which source is authoritative, the standalone endpoint `GET /api/admin/employee-totals` or `employeeTotals` in `GET /api/collections`?
2. If collections, where does the totals row come from?
3. Do `from` and `to` apply only to the standalone endpoint?
4. Does the collections row carry `pendingUnits`, `rejectedCount`, `employeeId`, and `cashOutstandingUnits`?
5. Does missing `currency` mean LYD, and can an item's currency differ from the report's?
6. Is `generatedAt` ISO-8601, and is `version` the same as the collections version?

Other questions that are not in PR #5's list:

7. When an employee uses an id outside their own data (assignment, submission, unlinked receipt, payroll movement, or a card outside their section), is the response **404** with a generic body that contains no name, amount, phone, or other id, or **403**? Apply **401** first when there is no session, then **404** for an id outside scope, then **403** for a forbidden action on an id that is in scope. A management route with no resource id (close day, financial ledger, employee totals) stays **403**. Does `GET /api/collections` and `GET /api/collections/payroll` for an employee return only that employee's rows (assignments by `assigneeUserId`, submissions and unlinked receipts by `submittedByUserId`, payroll by `userId`, and that employee's own metrics)? **Open question for Ali:** must the server omit `employeeTotals` for an employee? That omission is not a requirement of this proposal. [PR #35](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/35) already restricts the fake to the caller's rows, including `employeeTotals` rows whose `userId` is the caller (`userId` on that field is unconfirmed). The UI hides the totals block unless `collections.decide` is granted.
8. Does `POST /api/auth/logout` invalidate the cookie on the server before the response, so replaying that cookie returns **401** on `GET /api/me` and on writes? After the call the app wipes the cookie jar, the token store, and the in-memory CSRF token even if the call failed. PR #5's cookie-flag question is not this question.
9. Is `requestId` idempotent on collection, card, treasury, purchase, and masraweya writes, so a manual retry after **401** or **419** returns the first success and does not apply twice? PR #5's idempotency note is only about account-request decisions. Writes are never auto-replayed. `pendingMutationProvider` keeps the `requestId` in memory for the same user, the same inputs, and the same expected version, including after the form is disposed. A later manual submit of that same draft reuses it.
