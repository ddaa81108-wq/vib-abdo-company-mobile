#!/usr/bin/env bash
# Staging permission checks. CI passes --dry-run and does not contact a host.
# Live mode is read-only unless --allow-sandbox-writes is passed. That flag
# is for a clean sandbox only, with Ali's explicit approval each time.
# It is not an environment variable. Live mode reads STAGING_* from the local
# environment and refuses production hosts. It refuses to run when CI or
# GITHUB_ACTIONS is set to any non-empty value, so GitHub never sends it.
# Each account is logged in once per run. Login data stays on the bot machine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
exec dart tool/staging_negative_tests/staging_negative_tests.dart "$@"
