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
)

# Negative permission gate, staging preflight, and the release fake-API checks.
# The release APK byte scan runs in CI (it needs an Android SDK). The compile
# probe below does not.
tool/run_permissions_negative_tests.sh
bash tool/staging_negative_tests/preflight_test.sh
python3 tool/scan_release_apk.py --self-test
tool/check_release_rejects_fake_api.sh
