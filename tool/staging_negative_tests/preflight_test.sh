#!/usr/bin/env bash
# Offline checks for the staging preflight. Values here are placeholders, not accounts.
set -euo pipefail
cd "$(dirname "$0")/../.."

preflight() {
  # A clean environment so a developer shell cannot feed real secrets into this check.
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" \
    "$@" python3 tool/staging_negative_tests/preflight.py
}

expect_status() {
  local want="$1"
  shift
  local out
  set +e
  out="$(preflight "$@" 2>/dev/null)"
  local code=$?
  set -e
  local status
  status="$(printf '%s\n' "$out" | awk -F= '$1=="status"{print $2}')"
  if [[ "$status" != "$want" ]]; then
    echo "expected status=$want, got:"
    printf '%s\n' "$out"
    exit 1
  fi
  if [[ "$want" == "refuse" && "$code" -eq 0 ]]; then
    echo "refuse must exit non-zero"
    printf '%s\n' "$out"
    exit 1
  fi
  if [[ "$want" != "refuse" && "$code" -ne 0 ]]; then
    echo "status=$want must exit 0"
    printf '%s\n' "$out"
    exit 1
  fi
  printf '%s\n' "$out"
}

required=(
  STAGING_ADMIN_USERNAME=admin-placeholder
  STAGING_ADMIN_PASSWORD=placeholder-pass
  STAGING_EMPLOYEE_USERNAME=employee-placeholder
  STAGING_EMPLOYEE_PASSWORD=placeholder-pass
  STAGING_EMPLOYEE2_USERNAME=employee-two-placeholder
  STAGING_EMPLOYEE2_PASSWORD=placeholder-pass
)

echo "== missing secrets skip =="
out="$(expect_status skip)"
printf '%s\n' "$out" | grep -q 'missing=STAGING_API_BASE'

echo "== staging origin is ready =="
out="$(expect_status ready STAGING_API_BASE=https://staging.company.test "${required[@]}")"
printf '%s\n' "$out" | grep -q 'limited_manager=absent'

echo "== api-staging label is ready =="
expect_status ready STAGING_API_BASE=https://api-staging.company.test:8443 "${required[@]}" >/dev/null

echo "== test label on a normal TLD is ready =="
expect_status ready STAGING_API_BASE=https://test.company.com "${required[@]}" >/dev/null

echo "== limited-manager pair present =="
out="$(expect_status ready \
  STAGING_API_BASE=https://test.company.test \
  "${required[@]}" \
  STAGING_LIMITED_MANAGER_USERNAME=limited-placeholder \
  STAGING_LIMITED_MANAGER_PASSWORD=placeholder-pass)"
printf '%s\n' "$out" | grep -q 'limited_manager=present'

echo "== half of the optional pair refuses =="
out="$(expect_status refuse \
  STAGING_API_BASE=https://staging.company.test \
  "${required[@]}" \
  STAGING_LIMITED_MANAGER_USERNAME=limited-placeholder)"
printf '%s\n' "$out" | grep -q 'reason=partial-optional-secret'

echo "== production labels refuse =="
expect_status refuse STAGING_API_BASE=https://prod.company.test "${required[@]}" \
  | grep -q 'reason=looks-like-production'
expect_status refuse STAGING_API_BASE=https://staging.prod.company.test "${required[@]}" \
  | grep -q 'reason=looks-like-production'
expect_status refuse STAGING_API_BASE=https://live.company.test "${required[@]}" \
  | grep -q 'reason=looks-like-production'
expect_status refuse STAGING_API_BASE=https://api.production.company.test "${required[@]}" \
  | grep -q 'reason=looks-like-production'

echo "== non-staging origins refuse =="
expect_status refuse STAGING_API_BASE=https://api.company.test "${required[@]}" \
  | grep -q 'reason=not-staging-origin'
expect_status refuse STAGING_API_BASE=https://staging.example.invalid "${required[@]}" \
  | grep -q 'reason=not-staging-origin'
expect_status refuse STAGING_API_BASE=http://staging.company.test "${required[@]}" \
  | grep -q 'reason=not-staging-origin'
expect_status refuse STAGING_API_BASE=https://staging.company.test/api "${required[@]}" \
  | grep -q 'reason=not-staging-origin'
expect_status refuse STAGING_API_BASE=https://user:secret@staging.company.test "${required[@]}" \
  | grep -q 'reason=not-staging-origin'

echo "== whitespace-only secret counts as missing =="
out="$(expect_status skip STAGING_API_BASE='   ' "${required[@]}")"
printf '%s\n' "$out" | grep -q 'missing=STAGING_API_BASE'

echo "preflight_test ok"
