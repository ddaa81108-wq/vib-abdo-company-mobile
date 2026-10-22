#!/usr/bin/env bash
# P7-24 and P7-25 on a booted emulator, or a phone when PERF_SURFACE=device.
# Profile build, Fake API, FAKE_DATASET=large. No secrets.
# This is not the protocol release install.
# 32 ms / 16.7 ms frame budgets are engineering proposals. Ali sets acceptance.
# RSS/PSS from dumpsys meminfo are report-only.
set -euo pipefail
cd "$(dirname "$0")/.."

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

SURFACE="${PERF_SURFACE:-emulator}"
if [[ "$SURFACE" == "device" ]]; then
  DEVICE=$(adb devices | awk '/\tdevice$/{print $1; exit}')
else
  SURFACE=emulator
  DEVICE=$(adb devices | awk '/^emulator-/{print $1; exit}')
fi
if [[ -z "${DEVICE}" ]]; then
  echo "No ${SURFACE} adb device is connected."
  adb devices
  exit 1
fi

API=$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')
echo "P7-26 ${SURFACE} $DEVICE API $API (profile, Fake large dataset)"
echo "Frame budgets 32ms and 16.7ms are engineering proposals, not acceptance thresholds. Acceptance thresholds are set by Ali."
LOG="${PHASE7_LOG:-phase7-long-history.log}"
MEMLOG="${LOG}.mem"
: > "$LOG"
: > "$MEMLOG"
PKG=com.example.vib_abdo_company_mobile

# Report-only. A missing dumpsys field or a dead process does not fail the job.
capture_meminfo() {
  local when="$1"
  local raw="meminfo-${when}.txt"
  if ! adb -s "$DEVICE" shell dumpsys meminfo "$PKG" > "$raw" 2>/dev/null; then
    echo "PHASE7 p7_24_meminfo_${when}_pss_kb=unavailable" >> "$MEMLOG"
    echo "PHASE7 p7_24_meminfo_${when}_rss_kb=unavailable" >> "$MEMLOG"
    echo "PHASE7 p7_24_meminfo_${when}_source=dumpsys-meminfo" >> "$MEMLOG"
    echo "PHASE7 p7_24_meminfo_kind=report-only" >> "$MEMLOG"
    return 0
  fi
  if ! python3 tool/phase7_meminfo.py --when "$when" --file "$raw" >> "$MEMLOG"; then
    echo "PHASE7 p7_24_meminfo_${when}_pss_kb=unavailable" >> "$MEMLOG"
    echo "PHASE7 p7_24_meminfo_${when}_rss_kb=unavailable" >> "$MEMLOG"
    echo "PHASE7 p7_24_meminfo_kind=report-only" >> "$MEMLOG"
  fi
}

marker_seen() {
  local marker="$1"
  if grep -q "$marker" "$LOG" 2>/dev/null; then
    return 0
  fi
  adb -s "$DEVICE" logcat -d 2>/dev/null | grep -q "$marker"
}

set +e
adb -s "$DEVICE" logcat -c >/dev/null 2>&1
# HISTORY_WINDOW_TRIM is not passed, so the compile-time default (on) applies.
# The profile drive prints scroll markers and
# pauses so dumpsys can sample the live process. Memory never changes status.
flutter drive \
  --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/p7_long_history_test.dart \
  -d "$DEVICE" \
  --dart-define=USE_FAKE_API=true \
  --dart-define=FAKE_DATASET=large \
  --dart-define=FAKE_LATENCY_MS=0 \
  --dart-define=PERF_SURFACE="$SURFACE" \
  --dart-define=PHASE7_SAMPLE_MEMINFO=true \
  > "$LOG" 2>&1 &
drive_pid=$!
sampled_before=0
sampled_after=0
while kill -0 "$drive_pid" 2>/dev/null; do
  if [[ "$sampled_before" -eq 0 ]] && marker_seen "PHASE7 p7_24_scroll_begin=1"; then
    capture_meminfo before
    sampled_before=1
  fi
  if [[ "$sampled_after" -eq 0 ]] && marker_seen "PHASE7 p7_24_scroll_end=1"; then
    capture_meminfo after
    sampled_after=1
  fi
  sleep 1
done
wait "$drive_pid"
status=$?
set -e

if [[ "$sampled_before" -eq 0 ]]; then
  echo "PHASE7 p7_24_meminfo_before_pss_kb=unavailable" >> "$MEMLOG"
  echo "PHASE7 p7_24_meminfo_before_rss_kb=unavailable" >> "$MEMLOG"
  echo "PHASE7 p7_24_meminfo_kind=report-only" >> "$MEMLOG"
fi
if [[ "$sampled_after" -eq 0 ]]; then
  echo "PHASE7 p7_24_meminfo_after_pss_kb=unavailable" >> "$MEMLOG"
  echo "PHASE7 p7_24_meminfo_after_rss_kb=unavailable" >> "$MEMLOG"
  echo "PHASE7 p7_24_meminfo_kind=report-only" >> "$MEMLOG"
fi

{
  echo "PHASE7 p7_26_api=$API"
  echo "PHASE7 p7_26_surface=$SURFACE"
  echo "PHASE7 p7_24_profile=true"
  echo "PHASE7 p7_25_dataset=large"
  echo "PHASE7 p7_24_budget_kind=engineering-proposal"
  echo "PHASE7 p7_24_acceptance_threshold=set-by-ali"
  echo "PHASE7 proposal_device_cold_start_ms=5000"
  echo "PHASE7 proposal_emulator_cold_start_ms=20000"
  echo "PHASE7 proposal_login_home_hang_ms=60000"
  echo "PHASE7 proposal_device_worst_build_ms=32"
  echo "PHASE7 proposal_device_average_build_ms=16.7"
  echo "PHASE7 proposal_widget_walk_ms=8000"
  cat "$MEMLOG"
} >> "$LOG"

cat "$LOG"

python3 tool/phase7_summary.py \
  --title "P7-24 P7-25 P7-26 API $API" \
  --log "$LOG" \
  --out "phase7-long-history-api-${API}.md" \
  ${GITHUB_STEP_SUMMARY:+--summary "$GITHUB_STEP_SUMMARY"}

exit "$status"
