#!/usr/bin/env bash
# Staging permission checks. CI passes --dry-run and does not contact a host.
# Live mode reads STAGING_* from the local environment and refuses production
# hosts. It also refuses to run when CI or GITHUB_ACTIONS is set, so GitHub
# never sends it. Login data stays on the bot machine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
exec dart tool/staging_negative_tests/staging_negative_tests.dart "$@"
