#!/usr/bin/env bash
# Prove a release compilation rejects USE_FAKE_API=true and accepts false.
# Uses flutter test as the compiler so this does not need a Gradle APK.
# The CI release job also builds an APK and scans it.
set -euo pipefail
cd "$(dirname "$0")/.."

log="$(mktemp)"
echo "== release define USE_FAKE_API=true must fail compilation =="
set +e
(
  cd packages/api_layer
  flutter test test/release_fake_api_guard_test.dart \
    --reporter expanded \
    --dart-define=dart.vm.product=true \
    --dart-define=USE_FAKE_API=true
) >"$log" 2>&1
status=$?
set -e
if [[ "$status" -eq 0 ]]; then
  echo "Release compilation accepted USE_FAKE_API=true."
  cat "$log"
  exit 1
fi
if ! grep -q "Release builds cannot use the fake API" "$log"; then
  echo "Release+fake failed, but not because of the fake-API guard."
  cat "$log"
  exit 1
fi
echo "Release compilation rejected USE_FAKE_API=true."

echo "== release define USE_FAKE_API=false must compile =="
(
  cd packages/api_layer
  flutter test test/release_fake_api_guard_test.dart \
    --reporter expanded \
    --dart-define=dart.vm.product=true \
    --dart-define=USE_FAKE_API=false
)
rm -f "$log"
