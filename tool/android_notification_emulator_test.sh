#!/usr/bin/env bash
# Notification permission checks on a booted Android emulator.
# Debug build, USE_FAKE_API=true. No Firebase file and no secrets.
set -euo pipefail
cd "$(dirname "$0")/.."

PKG=com.vip2100.vib
PERM=android.permission.POST_NOTIFICATIONS

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
echo "Emulator $DEVICE API $API"
case "$API" in
  ''|*[!0-9]*)
    echo "Could not read the SDK version."
    exit 1
    ;;
esac

flutter pub get

run_case() {
  local mode="$1"
  echo "=== NOTIF_CASE=$mode ==="
  # Install first, then set the permission, then let flutter test replace the
  # APK with -r so the grant or revoke is already in place at launch.
  flutter build apk --debug \
    --target=integration_test/android_notifications_test.dart \
    --dart-define=USE_FAKE_API=true \
    --dart-define=NOTIF_CASE="$mode"
  adb -s "$DEVICE" install -r -t build/app/outputs/flutter-apk/app-debug.apk
  if [[ "$API" -ge 33 ]]; then
    if [[ "$mode" == "granted" ]]; then
      adb -s "$DEVICE" shell pm grant "$PKG" "$PERM"
      adb -s "$DEVICE" shell appops set "$PKG" POST_NOTIFICATION allow || true
    elif [[ "$mode" == "denied" ]]; then
      adb -s "$DEVICE" shell pm revoke "$PKG" "$PERM" || true
      adb -s "$DEVICE" shell appops set "$PKG" POST_NOTIFICATION deny || true
    fi
  fi
  flutter test integration_test/android_notifications_test.dart \
    -d "$DEVICE" \
    --dart-define=USE_FAKE_API=true \
    --dart-define=NOTIF_CASE="$mode" \
    --reporter expanded \
    --ignore-timeouts
}

if [[ "$API" -lt 33 ]]; then
  run_case implicit
else
  run_case denied
  run_case granted
fi
