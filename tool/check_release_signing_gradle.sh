#!/usr/bin/env bash
# Behaviour check for the release signing rules in android/app/build.gradle.kts.
# Runs Gradle in dry-run mode (-m), so nothing is compiled or signed. Uses only
# a throwaway keystore created in a temp dir; never the real release key.
#
# Cases:
#   1. partial env (alias only)                      -> release fails
#   2. ANDROID_KEY_PROPERTIES -> empty file           -> release fails
#   3. ANDROID_KEY_PROPERTIES -> wrong key names      -> release fails
#   4. ANDROID_REQUIRE_RELEASE_SIGNING=true, nothing  -> release fails
#   5. no material                                    -> release ok + warning
#   6. REQUIRE=true + no material, debug task         -> debug ok
#   7. complete throwaway key via key.properties      -> release ok, no warning
#
# Needs JDK 17, the Android SDK and android/local.properties (flutter.sdk).
# Not part of required CI (it adds Gradle configuration time); run locally.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

if [[ -e android/key.properties ]]; then
  echo "android/key.properties exists; move it away before running this check." >&2
  exit 2
fi
if [[ ! -f android/local.properties ]]; then
  flutter build apk --config-only >/dev/null
fi

TMP=$(mktemp -d /tmp/vib-signing-check.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

# Throwaway PKCS12 key. The random password stays in a file and env var.
head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' > "$TMP/pass"
keytool -genkeypair -keystore "$TMP/throwaway.p12" -storetype PKCS12 \
  -alias throwaway -keyalg RSA -keysize 2048 -validity 2 \
  -dname "CN=Throwaway Test" \
  -storepass:file "$TMP/pass" -keypass:file "$TMP/pass" >/dev/null 2>&1
{
  echo "storeFile=$TMP/throwaway.p12"
  printf 'storePassword=%s\n' "$(cat "$TMP/pass")"
  echo "keyAlias=throwaway"
} > "$TMP/good.properties"
: > "$TMP/empty.properties"
printf 'keystore=%s\nalias=throwaway\n' "$TMP/throwaway.p12" > "$TMP/wrong.properties"

failures=0
run_case() {
  # run_case <name> <expect ok|fail> <grep-required|-> <grep-forbidden|-> <task> [VAR=value ...]
  local name=$1 expect=$2 want=$3 forbid=$4 task=$5
  shift 5
  local log="$TMP/$(echo "$name" | tr -c 'A-Za-z0-9' _).log"
  local status=0
  (
    cd android
    env -u ANDROID_KEY_PROPERTIES -u ANDROID_KEYSTORE_PATH -u ANDROID_KEYSTORE_PASSWORD \
      -u ANDROID_KEY_ALIAS -u ANDROID_KEY_PASSWORD -u ANDROID_REQUIRE_RELEASE_SIGNING \
      "$@" ./gradlew -q -m --console=plain "$task"
  ) >"$log" 2>&1 || status=$?
  local ok=1
  if [[ $expect == ok && $status -ne 0 ]] || [[ $expect == fail && $status -eq 0 ]]; then ok=0; fi
  if [[ $want != - ]] && ! grep -q -- "$want" "$log"; then ok=0; fi
  if [[ $forbid != - ]] && grep -q -- "$forbid" "$log"; then ok=0; fi
  # No password value may ever reach the output.
  if grep -qF -- "$(cat "$TMP/pass")" "$log"; then ok=0; echo "  password leaked in output" >&2; fi
  if [[ $ok -eq 1 ]]; then
    printf '| %-52s | PASS |\n' "$name"
  else
    printf '| %-52s | FAIL (exit %s) |\n' "$name" "$status"
    sed -n '1,40p' "$log" | grep -vF -- "$(cat "$TMP/pass")" >&2 || true
    failures=$((failures + 1))
  fi
}

start=$(date +%s)
run_case "partial env (alias only) fails" fail "key alias\|keystore path" - :app:assembleRelease \
  ANDROID_KEY_ALIAS=throwaway
run_case "empty ANDROID_KEY_PROPERTIES file fails" fail "Release signing is incomplete" - :app:assembleRelease \
  ANDROID_KEY_PROPERTIES="$TMP/empty.properties"
run_case "wrong key names fail and are named" fail "unknown key names" - :app:bundleRelease \
  ANDROID_KEY_PROPERTIES="$TMP/wrong.properties"
run_case "REQUIRE=true with no material fails" fail "Release signing is incomplete" - :app:assembleRelease \
  ANDROID_REQUIRE_RELEASE_SIGNING=true
run_case "no material: release ok with debug-key warning" ok "signed with the DEBUG keystore" - :app:assembleRelease
run_case "REQUIRE=true, no material: debug build ok" ok - "Release signing is incomplete" :app:assembleDebug \
  ANDROID_REQUIRE_RELEASE_SIGNING=true
run_case "throwaway key + REQUIRE=true: release ok" ok - "DEBUG keystore" :app:assembleRelease \
  ANDROID_KEY_PROPERTIES="$TMP/good.properties" ANDROID_REQUIRE_RELEASE_SIGNING=true
echo "elapsed: $(( $(date +%s) - start ))s"

if [[ $failures -ne 0 ]]; then
  echo "release signing gradle check: $failures case(s) failed" >&2
  exit 1
fi
echo "release signing gradle check ok"
