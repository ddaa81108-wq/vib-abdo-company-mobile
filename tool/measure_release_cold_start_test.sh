#!/usr/bin/env bash
# Offline check for the P7-23 login-path guard. No adb, no flutter, no network.
# The release job does not pass --login-guard-only, so this never replaces
# the unauthenticated first-frame measurement.
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT="tool/measure_release_cold_start.sh"
WORKFLOW=".github/workflows/android-performance.yml"
BASE="https://staging.company.test"
PASSWORD="do-not-print-this-password"
PROPS="android/gradle.properties"
before="$(cksum "$PROPS")"

run_guard() {
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" \
    STAGING_API_BASE="$BASE" \
    "$@" \
    bash "$SCRIPT" --login-guard-only
}

fail() {
  echo "fail: $1"
  printf '%s\n' "$2"
  exit 1
}

assert_refused() {
  local label="$1"
  shift
  local out
  out="$(run_guard "$@" STAGING_ADMIN_USERNAME=admin STAGING_ADMIN_PASSWORD="$PASSWORD")"
  printf '%s\n' "$out" | grep -qx 'login_timing=0' || fail "$label login_timing" "$out"
  printf '%s\n' "$out" | grep -q 'P7-23 login timing refused' || fail "$label message" "$out"
  printf '%s\n' "$out" | grep -q 'unauthenticated release cold start still runs' || fail "$label still-runs" "$out"
  if printf '%s\n' "$out" | grep -q 'will use the local environment'; then
    fail "$label enabled login" "$out"
  fi
  if printf '%s\n' "$out" | grep -q "$PASSWORD"; then
    fail "$label printed the password" "$out"
  fi
  if printf '%s\n' "$out" | grep -Eq 'adb|flutter build|gradle.properties'; then
    fail "$label continued past the guard" "$out"
  fi
}

echo "== CI and GITHUB_ACTIONS refuse login timing =="
for value in true 1 false yes TRUE; do
  assert_refused "CI=$value" "CI=$value"
  assert_refused "GITHUB_ACTIONS=$value" "GITHUB_ACTIONS=$value"
done
assert_refused "CI blank-padded false" "CI= false "

echo "== blank or unset CI still times a local login =="
for assignment in "CI=" "CI=   " "GITHUB_ACTIONS="; do
  out="$(run_guard "$assignment" STAGING_ADMIN_USERNAME=admin STAGING_ADMIN_PASSWORD="$PASSWORD")"
  printf '%s\n' "$out" | grep -qx 'login_timing=1' || fail "$assignment login_timing" "$out"
  printf '%s\n' "$out" | grep -q 'will use the local environment' || fail "$assignment local" "$out"
  if printf '%s\n' "$out" | grep -q 'login timing refused'; then
    fail "$assignment refused a blank value" "$out"
  fi
  if printf '%s\n' "$out" | grep -q "$PASSWORD"; then
    fail "$assignment printed the password" "$out"
  fi
done

out="$(run_guard STAGING_ADMIN_USERNAME=admin STAGING_ADMIN_PASSWORD="$PASSWORD")"
printf '%s\n' "$out" | grep -qx 'login_timing=1' || fail "unset CI login_timing" "$out"

echo "== missing credentials skip login without the GitHub refusal =="
out="$(run_guard)"
printf '%s\n' "$out" | grep -qx 'login_timing=0' || fail "no creds login_timing" "$out"
printf '%s\n' "$out" | grep -q 'login timing skipped' || fail "no creds skip message" "$out"
if printf '%s\n' "$out" | grep -q 'login timing refused'; then
  fail "no creds used the GitHub refusal" "$out"
fi

echo "== guard does not edit the repo or take the login path on GitHub =="
after="$(cksum "$PROPS")"
if [[ "$before" != "$after" ]]; then
  echo "gradle.properties changed"
  exit 1
fi
python3 - "$SCRIPT" "$WORKFLOW" << 'PY'
import pathlib, sys
script = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
workflow = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
guard, _, rest = script.partition("login-guard-only")
if "exit " in guard.split("login timing refused", 1)[-1].split("elif", 1)[0]:
    sys.exit("refusal branch exits the script")
if "flutter build apk --release" not in rest or "am start -W" not in rest:
    sys.exit("unauthenticated cold start was removed")
if "STAGING_ADMIN_USERNAME" in rest.split("flutter drive", 1)[0]:
    sys.exit("first-frame path mentions the admin username")
job = workflow.split("release-cold-start:", 1)[1].split("\n  ", 1)[0]
# The job continues until the next top-level key. Keep the whole job.
job = workflow.split("  release-cold-start:", 1)[1]
if "script: bash tool/measure_release_cold_start.sh\n" not in job and \
   "script: bash tool/measure_release_cold_start.sh\r\n" not in job:
    # The line has no extra arguments.
    if "script: bash tool/measure_release_cold_start.sh" not in job:
        sys.exit("workflow no longer runs the cold-start script")
    line = [row for row in job.splitlines() if "measure_release_cold_start.sh" in row][0]
    if line.strip() != "script: bash tool/measure_release_cold_start.sh":
        sys.exit(f"workflow changed the cold-start invocation: {line.strip()}")
if "STAGING_ADMIN_USERNAME" in job or "STAGING_ADMIN_PASSWORD" in job:
    sys.exit("release-cold-start job reads staging login credentials")
if "secrets.STAGING_API_BASE" not in job:
    sys.exit("release-cold-start job dropped STAGING_API_BASE")
PY

echo "measure_release_cold_start_test ok"
