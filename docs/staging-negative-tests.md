# Staging negative tests

`tool/staging_negative_tests/run.sh` checks that a staging server, not the app, enforces the permission matrix. It is a Dart script. The shell entrypoint is the only command CI and humans should use.

## CI

CI runs:

```bash
tool/staging_negative_tests/run.sh --dry-run --junit "$RUNNER_TEMP/staging-negative-dry-run.xml"
```

`--dry-run` is a self-test. It does not read credentials and does not open a socket. It checks that missing env is refused, that production and non-staging hosts are refused, that the live case list is intact, and that JUnit XML escapes text. The workflow does not set any `STAGING_*` variable.

Live mode also refuses to run when `CI=true`, so a workflow edit cannot point this suite at a network by dropping `--dry-run`.

`flutter test --tags permissions-negative` is a separate CI step for the in-process tests. A failure fails the job. Those tests use the fake client and an in-process HTTP adapter.

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

`STAGING_API_BASE` must be `https` and the host must contain `staging`, or it must be loopback (`localhost`, `127.0.0.1`, `::1`) over `http` or `https`. A host label `prod` or `production` is refused even if the name also contains `staging`. Userinfo, a path, a query, and a fragment are refused. Redirects are not followed.

## Cases

The table printed at the end has one row per case: `PASS`, `FAIL`, or `SKIP`. Any `FAIL` exits 1. `SKIP` does not fail the run.

| Case | What it checks |
|---|---|
| `employee-management-endpoints` | Admin can log in. Admin `GET /api/admin/employee-totals` is 2xx or 404 (route not deployed), never 401 or 403. Employee calls management routes with a valid CSRF token and receives 403, or 404 where the matrix allows it. `GET /api/admin/employee-totals` must be 403 for the employee. |
| `employee-foreign-resource-ids` | Employee 2's collection ids are sent by employee 1. Expected status is 403 or 404, and the body must not contain employee 2's display name. Employee 1's `GET /api/collections` must not contain `employeeTotals` or employee 2's name. |
| `cookie-after-logout` | After `POST /api/auth/logout`, the same cookie on `GET /api/me` and on a write returns 401. |
| `csrf-missing-and-invalid` | A write with no `X-CSRF-Token`, and a write with a wrong token, return 400, 403, or 419, not 2xx. |
| `limited-manager-employee-totals` | Skipped when the limited-manager variables are unset. Otherwise `GET /api/admin/employee-totals` must be 403 until DEF-002 is decided. |

Passwords, cookies, and CSRF tokens are not printed. A failure line contains the path and the status code.

Employee 2 must have at least one collection assignment, submission, or unlinked receipt. If the overview has no id, that case fails instead of passing quietly.
