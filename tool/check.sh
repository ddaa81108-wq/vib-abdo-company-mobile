#!/usr/bin/env bash
# Analyze and test the app and the API package. No network calls.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter analyze
flutter test --exclude-tags screenshots

(
  cd packages/api_layer
  flutter analyze
  flutter test
  # Ledger dates must show the local calendar day (UTC+2), as in CI.
  TZ=Africa/Tripoli flutter test test/prod_compat_test.dart --plain-name "1 ledger dates"
)

# Negative permission gate, staging preflight, and the release fake-API checks.
# The release APK byte scan runs in CI (it needs an Android SDK). The compile
# probe below does not.
tool/run_permissions_negative_tests.sh
bash tool/staging_negative_tests/preflight_test.sh
python3 tool/scan_release_apk.py --self-test
tool/check_release_rejects_fake_api.sh

# Release signing rules (Gradle dry-run with a throwaway key in /tmp). Local
# only: required CI does not run this script, so it adds no CI time. Skipped
# when no Android SDK is configured.
if [[ -n "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]] && command -v keytool >/dev/null; then
  tool/check_release_signing_gradle.sh
else
  echo "release signing gradle check skipped: set ANDROID_HOME and JAVA_HOME to run it."
fi
