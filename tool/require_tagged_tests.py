#!/usr/bin/env python3
"""Fail when `flutter test --tags permissions-negative` ran zero tests.

Flutter exits 0 when every test is filtered out. The gate treats that as a
failure so a renamed tag or an empty suite cannot go green. Skipped-only
output (`+0`) is the same failure. A non-zero flutter exit is handled by the
caller; this script only judges the reporter output.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PROGRESS = re.compile(
    r"^[0-9:]+ \+(?P<passed>\d+)(?: ~(?P<skipped>\d+))?(?: -(?P<failed>\d+))?:",
    re.MULTILINE,
)
NONE = re.compile(r"No tests (?:ran|were found|match)", re.IGNORECASE)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: require_tagged_tests.py LOG LABEL", file=sys.stderr)
        return 2
    log = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    label = sys.argv[2]
    if NONE.search(log):
        return _fail(label, "the reporter said no tests ran")
    matches = list(PROGRESS.finditer(log))
    if not matches:
        return _fail(label, "could not find a flutter test summary line")
    last = matches[-1]
    passed = int(last.group("passed"))
    failed = int(last.group("failed") or 0)
    skipped = int(last.group("skipped") or 0)
    if passed + failed == 0:
        return _fail(
            label,
            f"0 tests ran (skipped {skipped}). "
            "Tag `permissions-negative` matched nothing.",
        )
    print(f"{label}: {passed} passed, {failed} failed, {skipped} skipped")
    return 0


def _fail(label: str, reason: str) -> int:
    print(
        f"permissions-negative gate failed for {label}: {reason}. "
        "See docs/TESTING.md.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
