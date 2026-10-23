# Staging negative tests

`tool/staging_negative_tests/run.sh` checks that a staging server, not the app, enforces the permission matrix. It is a Dart script. The shell entrypoint is the only command CI and humans should use.

## CI

The self-test is:

```bash
tool/staging_negative_tests/run.sh --dry-run --junit "$RUNNER_TEMP/staging-negative-dry-run.xml"
```

`--dry-run` does not read credentials and does not open a socket. It checks that missing env is refused, that production and non-staging hosts are refused, that a live run on GitHub is refused for any non-empty `CI` or `GITHUB_ACTIONS` value, that each account would be logged in once, that the live case list is intact, and that JUnit XML escapes text. It also prints the live case plan: each probe is `read` or part of a `write` / `mixed` case, and write probes show `skipped: write case, requires --allow-sandbox-writes` unless `--allow-sandbox-writes` is also passed. The flag does not open a socket during `--dry-run`. No workflow sets a `STAGING_*` username or password.

The required check `Negative permission tests` calls `tool/staging_negative_tests/run.sh --dry-run`. It does not call live mode. Live mode exits 2 when `CI` or `GITHUB_ACTIONS` is set to any non-empty value (`true`, `1`, `false`, `yes`, and any other text). Only an empty or unset value is allowed. A permission check against staging runs on the bot machine only. GitHub does not store staging usernames or passwords, neither as secrets nor as variables. The only staging secret the smoke workflow reads is `STAGING_API_BASE`. GitHub may reach staging without login, and only for the health check and the cold-start measurement.

`flutter test` on the app and on `packages/api_layer` includes the `permissions-negative` tests. Those tests use the fake client. A failure fails the job. That Fake API coverage is unchanged by keeping live mode off GitHub.

## Live run

Export these variables in the shell on the bot machine. Do not commit them. Do not store them in GitHub as secrets or as variables.

| Variable | Required |
|---|---|
| `STAGING_API_BASE` | Yes. Origin only. |
| `STAGING_ADMIN_USERNAME` | Yes |
| `STAGING_ADMIN_PASSWORD` | Yes |
| `STAGING_EMPLOYEE_USERNAME` | Yes |
| `STAGING_EMPLOYEE_PASSWORD` | Yes |
| `STAGING_EMPLOYEE2_USERNAME` | Yes. Second employee, used as the owner of ids the first employee must not read. |
| `STAGING_EMPLOYEE2_PASSWORD` | Yes |
| `STAGING_LIMITED_MANAGER_USERNAME` | No. If unset, the limited-manager case is `SKIP`. |
| `STAGING_LIMITED_MANAGER_PASSWORD` | No. Set both limited-manager variables or neither. |

```bash
export STAGING_API_BASE=https://staging.example.invalid
export STAGING_ADMIN_USERNAME=...
export STAGING_ADMIN_PASSWORD=...
export STAGING_EMPLOYEE_USERNAME=...
export STAGING_EMPLOYEE_PASSWORD=...
export STAGING_EMPLOYEE2_USERNAME=...
export STAGING_EMPLOYEE2_PASSWORD=...
tool/staging_negative_tests/run.sh
tool/staging_negative_tests/run.sh --junit /tmp/staging-negative.xml
```

There is no default host. The process exits 2 when a required variable is missing, and exits 2 before reading accounts when `CI` or `GITHUB_ACTIONS` is non-empty.

Live mode is read-only unless you pass `--allow-sandbox-writes`. Without that flag, only `GET` and `HEAD` probes run. Every `POST`, `PUT`, `PATCH`, and `DELETE` probe is skipped, and so is `GET /api/me` inside `cookie-after-logout`, because that read is only meaningful after logout. Each skipped probe prints:

```text
skipped: write case, requires --allow-sandbox-writes
```

`--allow-sandbox-writes` is a flag, not an environment variable. Do not set a `STAGING_*` name to turn writes on. Use the flag only against a clean sandbox environment, not shared staging data, and only with Ali's explicit approval for that run. Approval for one run does not carry to the next.

The script logs in once per account and reuses that cookie and CSRF token for every case of the account. `cookie-after-logout` runs after the other cases so logout does not invalidate the session those cases reuse. Login itself is not a negative write case.

Read-only mode does not log those accounts out. Logout is `POST /api/auth/logout`, so it is skipped unless `--allow-sandbox-writes` is set. A run with admin, employee, employee2, and the limited manager configured leaves those four staging sessions open. They stay open until the server expires them.

`run.sh` accepts the same origins as `classify_origin` in PR #32's `tool/staging_negative_tests/preflight.py`. It is not a stricter check.

- `https` only. No userinfo, path, query, or fragment. A non-default port is allowed.
- Placeholder hosts are refused: `*.invalid`, `*.example`, `example.com`, `localhost`, or a host containing `placeholder`, `changeme`, or `replace-me`. `https://staging.example.invalid` is refused. Loopback is refused.
- A DNS label other than the final label (the TLD) must be `staging`, `stage`, `test`, or `testing`, or contain `staging` / `testing`, or start with `stage-` / `test-`, or end with `-stage` / `-test`. The TLD does not count, so `https://api.company.test` is refused. Examples that pass: `https://staging.company.test`, `https://api-staging.company.test`, `https://test.company.test`.
- A label of `prod`, `production`, or `live`, a label containing `production`, or a label starting with `prod-` / `production-` / `live-` or ending with `-prod` / `-production` / `-live` is refused even when another label says staging.

Redirects are not followed. The value of the origin is not printed on refusal.

## Cases

The table printed at the end has one row per case: `PASS`, `FAIL`, or `SKIP`. Any `FAIL` exits 1. `SKIP` does not fail the run. `--dry-run` prints a second table, one row per probe, with the case access (`read`, `write`, or `mixed`) and whether that probe runs or is skipped.

| Case | Access | What it checks |
|---|---|---|
| `employee-management-endpoints` | mixed | Admin can log in. Admin `GET /api/admin/employee-totals` is 2xx or 404 (route not deployed), never 401 or 403. Employee `GET` management routes must be 403, or 404 where the matrix allows it. `GET /api/admin/employee-totals` must be 403 for the employee. Employee `POST` and `PUT` routes are write probes and are skipped unless `--allow-sandbox-writes` is set. |
| `employee-foreign-resource-ids` | mixed | Employee 1's `GET /api/collections` must not name employee 2 as a row owner: `employeeTotals[].userId`, `employeeTotals[].employeeId`, `assigneeUserId`, `submittedByUserId`, `employeeUserId`, and `recipientUserId` are compared exactly with employee 2's user id and employee id. A short id such as `u_20` counts. Text that only mentions the id does not. **Open question for Ali:** whether the server must omit `employeeTotals` for an employee. This suite does not fail when that array is present. `POST` of employee 2's ids is a write probe. Without `--allow-sandbox-writes` it is skipped and a missing id does not fail the case. With the flag, the expected status is 403 or 404, and a missing id fails the case. |
| `cookie-after-logout` | write | Skipped unless `--allow-sandbox-writes` is set. With the flag, after `POST /api/auth/logout`, the same cookie on `GET /api/me` and on a write returns 401. This case runs last so the single employee login is still valid for the earlier cases. |
| `csrf-missing-and-invalid` | write | Skipped unless `--allow-sandbox-writes` is set. With the flag, a write with no `X-CSRF-Token`, and a write with a wrong token, return 400, 403, or 419, not 2xx. These posts go to `/api/collections/unlinked-receipts` and can create a receipt if the server accepts them, which is why they are off by default. |
| `limited-manager-employee-totals` | read | Skipped when the limited-manager variables are unset. Otherwise `GET /api/admin/employee-totals` must be 403 until DEF-002 is decided. |

Passwords, cookies, and CSRF tokens are not printed. A failure line contains the path and the status code.

Employee 2 must have at least one collection assignment, submission, or unlinked receipt. If the overview has no id, that case fails instead of passing quietly.
