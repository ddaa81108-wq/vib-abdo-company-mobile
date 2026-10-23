#!/usr/bin/env bash
# Staging permission checks. CI passes --dry-run and does not contact a host.
# Live mode reads STAGING_* from the environment and refuses production hosts.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
exec dart tool/staging_negative_tests/staging_negative_tests.dart "$@"
