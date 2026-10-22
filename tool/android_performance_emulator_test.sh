#!/usr/bin/env bash
# P7-24 and P7-25 on a booted emulator.
# Profile build, Fake API, FAKE_DATASET=large. No secrets.
# This is not the protocol release install.
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

DEVICE=$(adb devices | awk '/^emulator-/{print $1; exit}')
if [[ -z "${DEVICE}" ]]; then
  echo "No emulator device is connected."
  adb devices
  exit 1
fi

API=$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')
echo "P7-26 emulator $DEVICE API $API (profile, Fake large dataset)"
LOG="${PHASE7_LOG:-phase7-long-history.log}"

set +e
flutter drive \
  --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/p7_long_history_test.dart \
  -d "$DEVICE" \
  --dart-define=USE_FAKE_API=true \
  --dart-define=FAKE_DATASET=large \
  --dart-define=FAKE_LATENCY_MS=0 \
  --dart-define=PERF_SURFACE=emulator \
  2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

{
  echo "PHASE7 p7_26_api=$API"
  echo "PHASE7 p7_26_surface=emulator"
  echo "PHASE7 p7_24_profile=true"
  echo "PHASE7 p7_25_dataset=large"
} >> "$LOG"

python3 tool/phase7_summary.py \
  --title "P7-24 P7-25 P7-26 API $API" \
  --log "$LOG" \
  --out "phase7-long-history-api-${API}.md" \
  ${GITHUB_STEP_SUMMARY:+--summary "$GITHUB_STEP_SUMMARY"}

exit "$status"
