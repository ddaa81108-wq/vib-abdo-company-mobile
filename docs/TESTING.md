# Testing

Negative permission tests are a required CI gate. Release builds cannot include the fake API or its demo profiles. Staging checks are a separate manual workflow and do not run on pull requests.

`tool/check.sh` runs analyze, the full test suites, the negative-permission gate, the staging preflight self-check, and the release compile probe. The release APK byte scan runs in GitHub Actions because it needs an Android SDK. Nothing here changes the application id or Android signing.

## Negative permission tests

Engineers adding a case that a role must *not* see or perform use one convention in both the app and `packages/api_layer`.

1. Declare the tag in `dart_test.yaml` (app) and `packages/api_layer/dart_test.yaml`:

   ```yaml
   tags:
     permissions-negative:
   ```

   The app file also keeps the `screenshots` tag. Do not remove it.

2. Put the test in a file named `*_permission_negative_test.dart`, or anywhere under `test/permissions/` as a `*_test.dart` file. Helpers in that folder that are not `*_test.dart` are fine.

3. Apply the tag to the whole file, with a `library;` directive:

   ```dart
   @Tags(['permissions-negative'])
   library;

   import 'package:flutter_test/flutter_test.dart';
   ```

   `@Tags` is exported by `flutter_test`. The annotation has to sit on the library, above the imports.

`tool/check_permissions_negative_convention.py` fails the build when a file breaks that shape, when a tagged file lives somewhere else, when either `dart_test.yaml` drops the tag, or when either package has zero of these tests.

Run only the gate:

```bash
tool/run_permissions_negative_tests.sh
```

That script runs, for the app and for `packages/api_layer`:

```bash
flutter test --tags permissions-negative --dart-define=USE_FAKE_API=true
```

Flutter exits 0 when the tag matches nothing (`No tests ran` or `+0`). This gate does not. **The build fails when zero tests ran**, including a skipped-only result. A real failure also fails the build. The full `flutter test` suite still runs these tests; the tagged command is the explicit gate so a renamed tag cannot go green.

The seed tests use the existing fake profiles (not new accounts):

- App: `test/permissions/treasury_section_permission_negative_test.dart`. `employee.demo` has no treasury code, so the home shell hides the section and the cash-in control, and a direct `/treasury` route does not open the screen.
- Package: `packages/api_layer/test/permissions/treasury_section_permission_negative_test.dart`. The same profile is rejected by `FakeApiClient` with `ForbiddenException` (HTTP 403) on a treasury read and a cash entry.

Add further cases the same way. Do not retag the older permission tests unless the file also moves to this name or directory.

### CI

Workflow name: `CI` (`.github/workflows/ci.yml`).

| Job | Check name | What it does |
| --- | --- | --- |
| `analyze-test-apk` | `Analyze, test, and debug APK` | Analyze, full tests, debug APK with `USE_FAKE_API=true`, then `tool/staging_negative_tests/run.sh --dry-run`. |
| `permissions-negative` | `Negative permission tests` | Convention check, tagged tests for the app and the package, fail on zero tests, then the same dry-run. |
| `release-no-fake-api` | `Release build rejects fake API` | Compile probe plus a release APK that must exist and scan clean. Described below. When `GOOGLE_SERVICES_JSON_BASE64` is set, that job decodes it before the successful release APK. See [NOTIFICATIONS.md](NOTIFICATIONS.md). |

Android notification permission on emulators is a separate workflow, `Android notification emulator` (`.github/workflows/android-notifications-emulator.yml`). It is not part of this required check. See [NOTIFICATIONS.md](NOTIFICATIONS.md).

Phase 7 startup, scroll, APK size, and the API 29/33/34 runs are another separate workflow, `Android performance` (`.github/workflows/android-performance.yml`). It is `workflow_dispatch` plus a nightly schedule. It does not run on pull requests and it does not add steps to the three required checks. Budgets, the device protocol, and what Ali provides are in [testing/PHASE7_PERFORMANCE.md](testing/PHASE7_PERFORMANCE.md). The acceptance matrix itself is `docs/acceptance/phase-7.md` on [PR #48](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/48), not in this branch.

`tool/staging_negative_tests/run.sh --dry-run` is an offline self-check. It does not read secrets and does not open a socket. The script is in this repo, so both CI jobs above run it and fail if it fails. The manual staging workflow is the only job that calls it without `--dry-run`. This repository does not add a second staging runner.

## Staging negative tests

Manual workflow: `.github/workflows/staging-negative-permissions.yml`, name `Staging negative permission tests`. It runs on `workflow_dispatch` only. The job is bound to the GitHub Environment `staging`, so it cannot be pointed at a production environment's secrets.

Create that environment (Settings → Environments → `staging`) and store the secrets there. Do not put production credentials in it. Optional protection rules (required reviewers) are a good idea and are not configured by this repo.

The workflow calls `tool/staging_negative_tests/run.sh` when that file is on the branch. **If the script is not in the checkout, the job skips with a notice and does not talk to a server.** Do not add another script under a different name. The integration engineer owns `run.sh`. This repo only supplies a thin preflight (`tool/staging_negative_tests/preflight.py`) that decides whether the workflow may invoke it.

`run.sh` contract, from the integration engineer:

- `--dry-run` is an offline self-check. Regular CI always runs it. The script is in the repo, so the step is not skipped.
- `--junit <file>` writes JUnit XML. The manual workflow passes `staging-permissions-junit.xml` and uploads that file as the artifact `staging-permissions-junit` (missing file warns; a test failure still fails the job).
- Non-zero exit if any test fails.
- The script refuses to run when its config is missing. The workflow does not call it in that case: missing required secrets **skip** the job with the secret names (never the values), so a button press before accounts exist is not a red build.

### Secret names

Set these on the `staging` environment. The workflow masks each value (`::add-mask::`) and never prints it. GitHub also masks `secrets.*` in later log lines.

| Secret | Required | Role |
| --- | --- | --- |
| `STAGING_API_BASE` | yes | Staging origin only (`https://host`, no path). Same name as the dart-define `API_BASE`. |
| `STAGING_ADMIN_USERNAME` | yes | Server role `admin`. |
| `STAGING_ADMIN_PASSWORD` | yes | Password for that admin. |
| `STAGING_EMPLOYEE_USERNAME` | yes | Server role `employee`. |
| `STAGING_EMPLOYEE_PASSWORD` | yes | Password for that employee. |
| `STAGING_EMPLOYEE2_USERNAME` | yes | A second `employee`, for cross-user cases. |
| `STAGING_EMPLOYEE2_PASSWORD` | yes | Password for the second employee. |
| `STAGING_LIMITED_MANAGER_USERNAME` | no | Limited manager. Pending DEF-002. |
| `STAGING_LIMITED_MANAGER_PASSWORD` | no | Password for that account. |

The optional pair is both or neither. One of the two set and the other empty **fails** the job (misconfiguration) and does not print the value. When both are absent, preflight reports `limited_manager=absent` and `run.sh` is expected to skip those cases.

Pass the variables through to `run.sh` as environment variables with these exact names. Do not commit them, and do not write them into a file in the repo.

### Origin check

Before `run.sh` is started, preflight refuses (exit 1, value not printed) unless `STAGING_API_BASE` is a staging or test origin:

- `https` only. No userinfo, path, query, or fragment. A non-default port is allowed.
- Placeholder hosts are not a staging origin: `*.invalid`, `*.example`, `example.com`, `localhost`, or a host containing `placeholder`, `changeme`, or `replace-me`. `https://staging.example.invalid` is refused.
- A DNS label other than the final label (the TLD) must be `staging`, `stage`, `test`, or `testing`, or contain `staging` / `testing`, or start with `stage-` / `test-`, or end with `-stage` / `-test`. The TLD itself does not count, so `https://api.company.test` is refused. Examples that pass: `https://staging.company.test`, `https://api-staging.company.test`, `https://test.company.test`.
- A label of `prod`, `production`, or `live`, a label containing `production`, or a label starting with `prod-` / `production-` / `live-` or ending with `-prod` / `-production` / `-live` refuses the run even if another label says staging. `https://api.company.test` (no staging or test label) is also refused.

If the real staging host does not match that shape, update `classify_origin` in `tool/staging_negative_tests/preflight.py` and the tests in `tool/staging_negative_tests/preflight_test.sh` in the same change. Do not weaken it to accept a production host.

### Adding role accounts

Accounts are created on the staging server, outside this repository.

1. Ask the server owner for one `admin`, two distinct `employee` users, and (when DEF-002 has a staging user) one limited manager. The app matches `role` only inside `PermissionService`, exactly `admin` or `employee`. Any other role grants nothing.
2. A repo admin adds the nine names above to the `staging` environment. The limited-manager pair can wait.
3. Confirm the host is the staging origin, not production, and that it matches the label rules above.
4. Run the workflow from the Actions tab once `tool/staging_negative_tests/run.sh` is on the branch you select. Download `staging-permissions-junit` from the run.

Until `run.sh` lands, the workflow skips. Regular CI still runs the tagged fake-API tests.

## Staging smoke (P-01)

Manual workflow: `.github/workflows/staging-smoke.yml`, name `Staging smoke`. It runs on `workflow_dispatch` only and is bound to the GitHub Environment `staging`. It is not one of the three required pull-request checks and does not call `tool/staging_negative_tests/run.sh`.

`STAGING_API_BASE` is a secret on the `staging` environment. A variable of the same name is an unrecommended fallback. The intended value is `https://staging.vip2100.com` with no `/erp` suffix. Empty and `/erp` fail the job. The job only runs unauthenticated `GET /api/health` via curl with User-Agent `VibAbdoMobileSmoke/1.0 (+github-actions)`. It does not read staging usernames or passwords, and those names are not stored in GitHub for this workflow, neither as secrets nor as variables. The login smoke runs locally on the bot machine only. After a login failure, do not run that local check more than once within 15 minutes (the login limit is 8 attempts per account). Dispatch steps and the secret table are in [api/staging-smoke.ar.md](api/staging-smoke.ar.md).

## Release builds and the fake API

`USE_FAKE_API` defaults to `true` so `flutter run`, `flutter test`, and the debug APK stay on the in-memory client. That default is wrong for a release binary.

`ReleaseFakeApiGuard` is a const assert on `dart.vm.product` (what Flutter sets for `--release`, and what `kReleaseMode` reads). **A release compile fails** when `USE_FAKE_API` is true or omitted:

```text
Release builds cannot use the fake API. Pass --dart-define=USE_FAKE_API=false.
```

Debug and profile do not set `dart.vm.product`, so they still compile the fake client. Profile is not a store build.

`ApiStack` also calls `rejectFakeApiInRelease` before constructing a fake client, so a hand-built `ApiConfig(useFakeApi: true)` throws in release even if the define was false. The factory calls the debug builder only when `kReleaseMode` is false, so release AOT tree-shakes that library. It also imports the fake client through a conditional import:

```dart
import 'fake_client_builder.dart'
    if (dart.vm.product) 'fake_client_builder_release.dart';
```

The release library does not import `FakeApiClient` or `fake_fixtures.dart`. Demo emails, display names, and the `demo-only` password are not in the release compilation unit.

Ship a release like this (origin from the server owner, not from git):

```bash
flutter build apk --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://staging.example
flutter build appbundle --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://staging.example
```

Real mode has no placeholder host. Omitting `API_BASE`, or passing a relative URL, a non-http(s) scheme, userinfo, a path, a query, or a fragment, throws `ApiConfigException` before a client is created. Fake mode ignores `API_BASE` and stores an empty `baseUrl`. Application id stays `com.example.vib_abdo_company_mobile`. Signing stays whatever `android/app/build.gradle.kts` already does (debug keystore until the release-signing work lands). This change does not edit either.

When a release workflow is added, it must pass `--dart-define=USE_FAKE_API=false`. Without that, the const assert fails the Dart compile.

### What CI checks

`tool/check_release_rejects_fake_api.sh` (also the `Release build rejects fake API` job):

1. `flutter test` the guard test with `--dart-define=dart.vm.product=true --dart-define=USE_FAKE_API=true` must fail, and the log must contain the message above.
2. The same test with `USE_FAKE_API=false` must pass.
3. `flutter build apk --release --dart-define=USE_FAKE_API=true` must fail with the same message, and must not be treated as a successful release build.

The job then builds:

```bash
flutter build apk --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://staging.example.com
```

`https://staging.example.com` is an origin `ApiConfig.requireRealBaseUrl` accepts (https, host only, no userinfo, path, query, or fragment). It is not a live host and not a secret. The staging preflight still refuses `*.example` as a `STAGING_API_BASE` value; that check is separate from this compile-time define. The job fails if `build/app/outputs/flutter-apk/app-release.apk` is missing or empty.

There is no `docs/RELEASE.md`. Optional Firebase config for the release APK, including the secret name `GOOGLE_SERVICES_JSON_BASE64`, is in [NOTIFICATIONS.md](NOTIFICATIONS.md). The decode runs only after the fake-API rejection check, and only when that secret is set.

`tool/scan_release_apk.py` reads the APK and fails if any of these appear as UTF-8 or UTF-16LE: the fixture emails and display names in `fake_fixtures.dart`, `demo-only`, and the `*.demo` usernames. The fixture needles must still occur in `fake_fixtures.dart`, so a rename cannot empty the scan. The APK is not uploaded. It is not a Play artifact.

`python3 tool/scan_release_apk.py --self-test` checks the scanner without an SDK.
