#!/usr/bin/env bash
# Run only the permissions-negative tag in the app and in packages/api_layer.
# Fails if flutter test fails, or if the tag matches zero tests.
# When tool/staging_negative_tests/run.sh exists, also runs its offline --dry-run.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 tool/check_permissions_negative_convention.py

run_dir() {
  local dir="$1"
  local log
  log="$(mktemp)"
  echo "== flutter test --tags permissions-negative ($dir) =="
  set +e
  (
    cd "$dir"
    flutter test --reporter expanded --tags permissions-negative \
      --dart-define=USE_FAKE_API=true
  ) 2>&1 | tee "$log"
  local status="${PIPESTATUS[0]}"
  set -e
  python3 tool/require_tagged_tests.py "$log" "$dir"
  rm -f "$log"
  if [[ "$status" -ne 0 ]]; then
    echo "permissions-negative tests failed in $dir (exit $status)"
    exit "$status"
  fi
}

run_dir "."
run_dir "packages/api_layer"

script="tool/staging_negative_tests/run.sh"
if [[ -f "$script" ]]; then
  echo "== $script --dry-run =="
  bash "$script" --dry-run
else
  echo "$script is not in this checkout."
  echo "Skipping the offline dry-run. This is expected until the integration script lands."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### Staging script dry-run"
      echo
      echo "Skipped: \`$script\` is absent. Negative permission tests still ran."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
fi
