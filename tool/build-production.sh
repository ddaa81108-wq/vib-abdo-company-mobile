#!/usr/bin/env bash
# Build on the machine that already owns the original signing key.
# Never copies signing material into GitHub, this repository, or build output.
set -euo pipefail
cd "$(dirname "$0")/.."

build_number="${1:-}"
if [[ ! "$build_number" =~ ^[1-9][0-9]{0,9}$ ]] || (( build_number > 2100000000 )); then
  echo 'Usage: bash tool/build-production.sh <version-code-higher-than-installed>' >&2
  exit 2
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo 'Commit or review tracked local changes before building a release.' >&2
  exit 2
fi
command -v flutter >/dev/null || { echo 'Flutter is not on PATH.' >&2; exit 2; }

if [[ -z "${ANDROID_KEY_PROPERTIES:-}" && -f /workspace/phase9/secrets/key.properties ]]; then
  export ANDROID_KEY_PROPERTIES=/workspace/phase9/secrets/key.properties
fi
if [[ -n "${ANDROID_KEY_PROPERTIES:-}" && ! -f "$ANDROID_KEY_PROPERTIES" ]]; then
  echo 'The configured signing properties file is missing.' >&2
  exit 2
fi
if [[ ! -f android/app/google-services.json ]]; then
  echo 'Production Firebase config must exist on this build machine: android/app/google-services.json.' >&2
  exit 2
fi

export ANDROID_REQUIRE_RELEASE_SIGNING=true
export ENABLE_GOOGLE_SERVICES=true
flutter pub get --enforce-lockfile
flutter build apk --release --build-number="$build_number" \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://vip2100.com \
  --dart-define=EMPLOYEE_TOTALS_SOURCE=collections \
  --dart-define=COLLECTIONS_WHITE_GOLD=true

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
bt="$sdk/build-tools/36.0.0"
if [[ ! -x "$bt/apksigner" || ! -x "$bt/aapt2" ]]; then
  echo 'Install Android build-tools 36.0.0 to verify the produced APK.' >&2
  exit 2
fi
apk=build/app/outputs/flutter-apk/app-release.apk
cert="$("$bt/apksigner" verify --print-certs "$apk")"
expected=40b569e6ffe89126ed81027a1b157e4dc4891319ec8c5449ae60206e08bbb841
if ! printf '%s\n' "$cert" | grep -Fqi "Signer #1 certificate SHA-256 digest: $expected"; then
  echo 'APK certificate differs from the documented original release certificate. Do not distribute.' >&2
  exit 2
fi
badging="$("$bt/aapt2" dump badging "$apk")"
if [[ "${badging%%$'\n'*}" != *"name='com.vip2100.vib' versionCode='$build_number'"* ]]; then
  echo 'Unexpected application id or version code. Do not distribute.' >&2
  exit 2
fi
python3 tool/scan_release_apk.py "$apk"

commit="$(git rev-parse --short=12 HEAD)"
mkdir -p build/releases
output="build/releases/vib-production-${commit}-${build_number}.apk"
cp "$apk" "$output"
sha256sum "$output" > "$output.sha256"
printf 'Verified production APK: %s\n' "$output"
printf 'Commit: %s\nVersion code: %s\n' "$commit" "$build_number"
