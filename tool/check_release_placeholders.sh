#!/usr/bin/env bash
# Pre-tag / pre-release check. Fails while docs/release/*.md still contain the
# placeholders <BUILD_COMMIT> or <PHASE9_MERGE_COMMIT>. Those placeholders are
# expected on main until the release, so this script is NOT part of
# tool/check.sh or CI. Run it after filling in the release docs and before
# creating the release tag. See docs/release/BUILD.ar.md.
set -euo pipefail
cd "$(dirname "$0")/.."

shopt -s nullglob
docs=(docs/release/*.md)
if [[ ${#docs[@]} -eq 0 ]]; then
  echo "no docs/release/*.md files found" >&2
  exit 2
fi

if grep -nE '<(BUILD_COMMIT|PHASE9_MERGE_COMMIT)>' "${docs[@]}"; then
  echo "release placeholders are still present (see above). Fill them in before tagging." >&2
  exit 1
fi
echo "release placeholders ok: none left in ${#docs[@]} files under docs/release/"
