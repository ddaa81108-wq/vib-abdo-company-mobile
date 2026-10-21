# Staging negative tests

`tool/staging_negative_tests/run.sh` checks that a staging server, not the app, enforces the permission matrix. It is a Dart script. The shell entrypoint is the only command CI and humans should use.

## CI

The self-test is:

```bash
tool/staging_negative_tests/run.sh --dry-run --junit "$RUNNER_TEMP/staging-negative-dry-run.xml"
```

`--dry-run` does not read credentials and does not open a socket. It checks that missing env is refused, that production and non-staging hosts are refused, that the live case list is intact, and that JUnit XML escapes text. No workflow sets a `STAGING_*` variable.

[PR #32](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/32) runs this entrypoint. Its negative-permission job calls `tool/staging_negative_tests/run.sh --dry-run` when the file exists. Its manual workflow `Staging negative permission tests` calls `run.sh --junit staging-permissions-junit.xml` and uploads that file as the artifact `staging-permissions-junit`. That live call happens on GitHub Actions, so this script does not refuse `CI=true`. This branch does not add a workflow step of its own.

`flutter test` on the app and on `packages/api_layer` includes the `permissions-negative` tests. Those tests use the fake client. A failure fails the job.

## Live run

Export these variables in the shell. Do not commit them.

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

There is no default host. The process exits 2 when a required variable is missing.

`run.sh` accepts the same origins as `classify_origin` in PR #32's `tool/staging_negative_tests/preflight.py`. It is not a stricter check.

- `https` only. No userinfo, path, query, or fragment. A non-default port is allowed.
- Placeholder hosts are refused: `*.invalid`, `*.example`, `example.com`, `localhost`, or a host containing `placeholder`, `changeme`, or `replace-me`. `https://staging.example.invalid` is refused. Loopback is refused.
- A DNS label other than the final label (the TLD) must be `staging`, `stage`, `test`, or `testing`, or contain `staging` / `testing`, or start with `stage-` / `test-`, or end with `-stage` / `-test`. The TLD does not count, so `https://api.company.test` is refused. Examples that pass: `https://staging.company.test`, `https://api-staging.company.test`, `https://test.company.test`.
- A label of `prod`, `production`, or `live`, a label containing `production`, or a label starting with `prod-` / `production-` / `live-` or ending with `-prod` / `-production` / `-live` is refused even when another label says staging.

Redirects are not followed. The value of the origin is not printed on refusal.

## Cases

The table printed at the end has one row per case: `PASS`, `FAIL`, or `SKIP`. Any `FAIL` exits 1. `SKIP` does not fail the run.

| Case | What it checks |
|---|---|
| `employee-management-endpoints` | Admin can log in. Admin `GET /api/admin/employee-totals` is 2xx or 404 (route not deployed), never 401 or 403. Employee calls management routes with a valid CSRF token and receives 403, or 404 where the matrix allows it. `GET /api/admin/employee-totals` must be 403 for the employee. |
| `employee-foreign-resource-ids` | Employee 2's collection ids are sent by employee 1. Expected status is 403 or 404, and the body must not contain employee 2's display name. Employee 1's `GET /api/collections` must not contain employee 2's name. **Open question for Ali:** whether the server must omit `employeeTotals` for an employee. This suite does not fail when that array is present. |
| `cookie-after-logout` | After `POST /api/auth/logout`, the same cookie on `GET /api/me` and on a write returns 401. |
| `csrf-missing-and-invalid` | A write with no `X-CSRF-Token`, and a write with a wrong token, return 400, 403, or 419, not 2xx. |
| `limited-manager-employee-totals` | Skipped when the limited-manager variables are unset. Otherwise `GET /api/admin/employee-totals` must be 403 until DEF-002 is decided. |

Passwords, cookies, and CSRF tokens are not printed. A failure line contains the path and the status code.

Employee 2 must have at least one collection assignment, submission, or unlinked receipt. If the overview has no id, that case fails instead of passing quietly.
