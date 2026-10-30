#!/usr/bin/env bash
# P7-23 and the release half of P7-26.
# Real mode. USE_FAKE_API=false. API_BASE comes from STAGING_API_BASE.
# Fails when that origin is unset or is not a staging host.
# Login-to-home timing runs only on the bot machine, when
# STAGING_ADMIN_USERNAME and STAGING_ADMIN_PASSWORD are already in the
# local environment and neither CI nor GITHUB_ACTIONS is set. Any
# non-empty value of those two names refuses the login path. The
# unauthenticated first-frame measurement (STAGING_API_BASE only) still
# runs. Does not print secret values.
# Does not upload the APK.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - << 'PY'
import os
import sys

sys.path.insert(0, "tool/staging_negative_tests")
from preflight import classify_origin

base = os.environ.get("STAGING_API_BASE", "").strip()
if not base:
    print("P7-23 blocked: STAGING_API_BASE is unset.")
    print("Set the secret STAGING_API_BASE on the GitHub environment staging.")
    print("This is not a product failure. The release job does not skip.")
    sys.exit(1)
kind = classify_origin(base)
if kind != "ok":
    print(f"P7-23 blocked: STAGING_API_BASE classify_origin={kind}.")
    print("The value is not printed. Use an https staging or test origin.")
    sys.exit(1)
print("P7-23 staging origin accepted. The value is not printed.")
PY

login_timing=0
# Any non-empty CI or GITHUB_ACTIONS value means this process is on GitHub.
# ${VAR-} keeps `set -u` quiet when the variable is unset. Stripping
# whitespace matches the staging negative runner: only empty or blank may
# time a login. The first-frame path below does not use a username or password.
ci_guard="${CI-}"
actions_guard="${GITHUB_ACTIONS-}"
ci_guard="${ci_guard//[[:space:]]/}"
actions_guard="${actions_guard//[[:space:]]/}"
if [[ -n "$ci_guard" || -n "$actions_guard" ]]; then
  echo "P7-23 login timing refused. CI or GITHUB_ACTIONS is set to a non-empty value."
  echo "Login-to-home timing uses staging usernames and passwords. GitHub does not store those."
  echo "The unauthenticated release cold start still runs."
elif [[ -n "${STAGING_ADMIN_USERNAME:-}" && -n "${STAGING_ADMIN_PASSWORD:-}" ]]; then
  login_timing=1
  echo "P7-23 login timing will use the local environment. Values are not printed."
else
  echo "P7-23 login timing skipped. Set STAGING_ADMIN_USERNAME and STAGING_ADMIN_PASSWORD on the bot machine to time login through home."
  echo "GitHub Actions does not read those names. They are not stored as secrets or variables."
fi

# Offline tests stop here. The release job never passes this flag, so the
# first-frame measurement below is unchanged.
if [[ "${1:-}" == "--login-guard-only" ]]; then
  echo "login_timing=$login_timing"
  exit 0
fi

python3 - << 'PY'
from pathlib import Path
path = Path("android/gradle.properties")
text = path.read_text(encoding="utf-8")
old = "org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError"
new = "org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError"
if old not in text:
    raise SystemExit("android/gradle.properties jvmargs changed; update the emulator heap override")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

adb start-server >/dev/null
adb wait-for-device
for _ in $(seq 1 60); do
  boot=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
  if [[ "$boot" == "1" ]]; then
    break
  fi
  sleep 2
done

DEVICE=$(adb devices | awk '/^emulator-/{print $1; exit}')
if [[ -z "${DEVICE}" ]]; then
  DEVICE=$(adb devices | awk '/\tdevice$/{print $1; exit}')
fi
if [[ -z "${DEVICE}" ]]; then
  echo "P7-23 blocked: no adb device."
  adb devices
  exit 1
fi

API=$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')
SURFACE="${PERF_SURFACE:-emulator}"
case "$SURFACE" in
  device) BUDGET=5000 ;;
  emulator) BUDGET=20000 ;;
  *)
    echo "P7-23 blocked: PERF_SURFACE must be emulator or device for this script."
    exit 1
    ;;
esac

echo "P7-26 release cold start on $DEVICE API $API surface $SURFACE"

# First-frame APK. API_BASE only. No username or password in this binary.
flutter build apk --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE="$STAGING_API_BASE" \
  --dart-define=PERF_SURFACE="$SURFACE"

APK=build/app/outputs/flutter-apk/app-release.apk
if [[ ! -f "$APK" ]]; then
  echo "P7-23 blocked: release APK was not produced."
  exit 1
fi

PKG=com.vip2100.vib
adb -s "$DEVICE" install -r "$APK" >/dev/null

times=()
for _ in 1 2 3; do
  adb -s "$DEVICE" shell am force-stop "$PKG" >/dev/null
  sleep 1
  output=$(adb -s "$DEVICE" shell am start -W -n "$PKG/.MainActivity" | tr -d '\r')
  total=$(printf '%s\n' "$output" | awk -F: '/TotalTime/{gsub(/ /,"",$2); print $2; exit}')
  if [[ -z "$total" ]]; then
    echo "P7-23 blocked: am start -W did not report TotalTime."
    printf '%s\n' "$output"
    exit 1
  fi
  times+=("$total")
done

median=$(printf '%s\n' "${times[@]}" | sort -n | awk 'NR==2')
echo "PHASE7 p7_23_total_time_ms=$median"
echo "PHASE7 p7_23_samples_ms=${times[*]}"
echo "PHASE7 p7_23_surface=$SURFACE"
echo "PHASE7 p7_23_api=$API"
echo "PHASE7 p7_23_budget_ms=$BUDGET"
echo "PHASE7 p7_23_budget_kind=engineering-proposal"
echo "PHASE7 p7_23_acceptance_threshold=set-by-ali"
echo "PHASE7 p7_23_acceptance=recorded"
echo "PHASE7 p7_26_api=$API"
echo "PHASE7 proposal_device_cold_start_ms=5000"
echo "PHASE7 proposal_emulator_cold_start_ms=20000"
echo "PHASE7 proposal_login_home_hang_ms=60000"
echo "PHASE7 proposal_device_worst_build_ms=32"
echo "PHASE7 proposal_device_average_build_ms=16.7"
echo "PHASE7 proposal_widget_walk_ms=8000"
echo "P7-23 budget ${BUDGET}ms on ${SURFACE} is an engineering proposal, not an acceptance threshold. Acceptance thresholds are set by Ali."

LOG="${PHASE7_LOG:-phase7-cold-start.log}"
{
  echo "PHASE7 p7_23_total_time_ms=$median"
  echo "PHASE7 p7_23_samples_ms=${times[*]}"
  echo "PHASE7 p7_23_surface=$SURFACE"
  echo "PHASE7 p7_23_api=$API"
  echo "PHASE7 p7_23_budget_ms=$BUDGET"
  echo "PHASE7 p7_23_budget_kind=engineering-proposal"
  echo "PHASE7 p7_23_acceptance_threshold=set-by-ali"
  echo "PHASE7 p7_23_acceptance=recorded"
  echo "PHASE7 p7_26_api=$API"
  echo "PHASE7 proposal_device_cold_start_ms=5000"
  echo "PHASE7 proposal_emulator_cold_start_ms=20000"
  echo "PHASE7 proposal_login_home_hang_ms=60000"
  echo "PHASE7 proposal_device_worst_build_ms=32"
  echo "PHASE7 proposal_device_average_build_ms=16.7"
  echo "PHASE7 proposal_widget_walk_ms=8000"
} > "$LOG"

# Scripted home time. This test APK embeds the admin dart-defines.
# Do not upload it. Run it only on the bot machine, where the names are set
# in the shell. GitHub Actions leaves them unset and skips this block.
status=0
if [[ "$login_timing" -eq 1 ]]; then
  set +e
  flutter drive \
    --release \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/p7_release_cold_start_test.dart \
    -d "$DEVICE" \
    --dart-define=USE_FAKE_API=false \
    --dart-define=API_BASE="$STAGING_API_BASE" \
    --dart-define=STAGING_ADMIN_USERNAME="$STAGING_ADMIN_USERNAME" \
    --dart-define=STAGING_ADMIN_PASSWORD="$STAGING_ADMIN_PASSWORD" \
    --dart-define=PERF_SURFACE="$SURFACE" \
    2>&1 | tee -a "$LOG"
  status=${PIPESTATUS[0]}
  set -e
else
  echo "PHASE7 p7_23_login_timing=local-only" | tee -a "$LOG"
fi

rm -rf build/app/outputs/flutter-apk build/app/outputs/apk || true

python3 tool/phase7_summary.py \
  --title "P7-23 P7-26 API $API" \
  --log "$LOG" \
  --out "phase7-cold-start-api-${API}.md" \
  ${GITHUB_STEP_SUMMARY:+--summary "$GITHUB_STEP_SUMMARY"}

if [[ "$median" -gt "$BUDGET" ]]; then
  echo "P7-23 engineering proposal exceeded: TotalTime ${median}ms > ${BUDGET}ms on ${SURFACE}."
  echo "This number is an engineering proposal, not an acceptance threshold. Acceptance thresholds are set by Ali."
  echo "Acceptance stays recorded. This is not a protocol Pass or Fail."
  status=1
fi

exit "$status"
