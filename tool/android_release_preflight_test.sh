#!/usr/bin/env bash
# Local checks for tool/android_release_preflight.sh. No network.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
preflight="$root/tool/android_release_preflight.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/pubspec.yaml" << 'EOF'
name: sample
version: 1.2.3+15
EOF

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $label" >&2
    echo "  got:  $got" >&2
    echo "  want: $want" >&2
    exit 1
  fi
}

assert_fail() {
  local label="$1"
  shift
  local err="$tmp/err"
  if "$@" >"$tmp/out" 2>"$err"; then
    echo "FAIL $label (expected non-zero)" >&2
    cat "$tmp/out" "$err" >&2
    exit 1
  fi
}

value_of() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$file"
}

run_version() {
  env -u GITHUB_OUTPUT -u GITHUB_STEP_SUMMARY \
    PUBSPEC="$tmp/pubspec.yaml" \
    EVENT_NAME="${EVENT_NAME-}" \
    GIT_TAG="${GIT_TAG-}" \
    INPUT_BUILD_NAME="${INPUT_BUILD_NAME-}" \
    INPUT_BUILD_NUMBER="${INPUT_BUILD_NUMBER-}" \
    "$preflight" version > "$tmp/out"
}

# Default pubspec resolution. A branch name in GIT_TAG is not a release tag.
EVENT_NAME=workflow_dispatch GIT_TAG=main INPUT_BUILD_NAME= INPUT_BUILD_NUMBER= run_version
assert_eq "$(value_of version_name "$tmp/out")" "1.2.3" "dispatch versionName"
assert_eq "$(value_of version_code "$tmp/out")" "15" "dispatch versionCode"
assert_eq "$(value_of version_regressed "$tmp/out")" "false" "dispatch not regressed"

# Tag must match pubspec versionName.
EVENT_NAME=push GIT_TAG=v1.2.3 INPUT_BUILD_NAME= INPUT_BUILD_NUMBER= run_version
assert_eq "$(value_of version_name "$tmp/out")" "1.2.3" "tag versionName"
assert_eq "$(value_of version_code "$tmp/out")" "15" "tag versionCode"

EVENT_NAME=push GIT_TAG=v1.2.3+15 INPUT_BUILD_NAME= INPUT_BUILD_NUMBER= run_version
assert_eq "$(value_of version_code "$tmp/out")" "15" "tag with code"

# Dispatch overrides apply. Tag pushes ignore overrides.
EVENT_NAME=workflow_dispatch GIT_TAG=v9.9.9 INPUT_BUILD_NAME=1.2.4 INPUT_BUILD_NUMBER=16 run_version
assert_eq "$(value_of version_name "$tmp/out")" "1.2.4" "override name"
assert_eq "$(value_of version_code "$tmp/out")" "16" "override code"

EVENT_NAME=workflow_dispatch GIT_TAG= INPUT_BUILD_NAME= INPUT_BUILD_NUMBER=9 run_version
assert_eq "$(value_of version_code "$tmp/out")" "9" "lower override code"
assert_eq "$(value_of version_regressed "$tmp/out")" "true" "lower override flagged"

EVENT_NAME=push GIT_TAG=v1.2.3 INPUT_BUILD_NAME=9.9.9 INPUT_BUILD_NUMBER=99 run_version
assert_eq "$(value_of version_name "$tmp/out")" "1.2.3" "tag ignores override name"
assert_eq "$(value_of version_code "$tmp/out")" "15" "tag ignores override code"

# Summary file receives the resolved version.
summary="$tmp/summary.md"
env -u GITHUB_OUTPUT \
  PUBSPEC="$tmp/pubspec.yaml" \
  GITHUB_STEP_SUMMARY="$summary" \
  EVENT_NAME=workflow_dispatch \
  "$preflight" version > "$tmp/out"
grep -q 'versionName: `1.2.3`' "$summary"
grep -q 'versionCode: `15`' "$summary"

# Failures.
assert_fail "tag mismatch" env PUBSPEC="$tmp/pubspec.yaml" EVENT_NAME=push GIT_TAG=v9.9.9 "$preflight" version
assert_fail "tag code mismatch" env PUBSPEC="$tmp/pubspec.yaml" EVENT_NAME=push GIT_TAG=v1.2.3+14 "$preflight" version
assert_fail "bad tag" env PUBSPEC="$tmp/pubspec.yaml" EVENT_NAME=push GIT_TAG=v1.2 "$preflight" version
assert_fail "bad build_name" env PUBSPEC="$tmp/pubspec.yaml" EVENT_NAME=workflow_dispatch INPUT_BUILD_NAME=1.2 "$preflight" version
assert_fail "bad build_number" env PUBSPEC="$tmp/pubspec.yaml" EVENT_NAME=workflow_dispatch INPUT_BUILD_NUMBER=01 "$preflight" version

printf 'version: 1.2.3\n' > "$tmp/pubspec.yaml"
assert_fail "pubspec missing code" env PUBSPEC="$tmp/pubspec.yaml" "$preflight" version
printf 'version: 1.2.3+0\n' > "$tmp/pubspec.yaml"
assert_fail "pubspec code zero" env PUBSPEC="$tmp/pubspec.yaml" "$preflight" version
printf 'version: 1.2.3+15\n' > "$tmp/pubspec.yaml"

# Secrets: all absent skips, all set builds, a partial set fails closed.
# Whitespace-only counts as absent. Values must not appear in the output.
env -u ANDROID_KEYSTORE_BASE64 -u ANDROID_KEYSTORE_PASSWORD -u ANDROID_KEY_ALIAS -u ANDROID_KEY_PASSWORD \
  -u GITHUB_OUTPUT \
  GITHUB_STEP_SUMMARY="$tmp/skip.md" \
  "$preflight" secrets > "$tmp/out"
assert_eq "$(value_of mode "$tmp/out")" "skip" "all secrets absent"
grep -q "Signed release skipped" "$tmp/skip.md"

env -u GITHUB_OUTPUT -u GITHUB_STEP_SUMMARY \
  ANDROID_KEYSTORE_BASE64='YQ==' \
  ANDROID_KEYSTORE_PASSWORD='store-secret' \
  ANDROID_KEY_ALIAS='upload' \
  ANDROID_KEY_PASSWORD='key-secret' \
  "$preflight" secrets > "$tmp/out"
assert_eq "$(value_of mode "$tmp/out")" "build" "all secrets set"
if grep -q 'store-secret\|key-secret\|YQ==' "$tmp/out"; then
  echo "FAIL secret values leaked to stdout" >&2
  exit 1
fi

assert_fail "partial secrets" env \
  ANDROID_KEYSTORE_BASE64='YQ==' \
  ANDROID_KEYSTORE_PASSWORD='store-secret' \
  ANDROID_KEY_ALIAS='' \
  ANDROID_KEY_PASSWORD='' \
  "$preflight" secrets
if grep -q 'store-secret' "$tmp/err"; then
  echo "FAIL secret value leaked on partial failure" >&2
  exit 1
fi
grep -q 'ANDROID_KEY_ALIAS' "$tmp/err"
grep -q 'ANDROID_KEY_PASSWORD' "$tmp/err"

env -u GITHUB_OUTPUT \
  ANDROID_KEYSTORE_BASE64='   ' \
  ANDROID_KEYSTORE_PASSWORD='' \
  ANDROID_KEY_ALIAS='' \
  ANDROID_KEY_PASSWORD='' \
  "$preflight" secrets > "$tmp/out"
assert_eq "$(value_of mode "$tmp/out")" "skip" "whitespace secrets count as unset"

echo "android release preflight ok"
