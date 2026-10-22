#!/usr/bin/env python3
"""Parse `adb shell dumpsys meminfo <package>` for report-only RSS and PSS.

The numbers are kilobytes from dumpsys. They are not a budget and they do
not pass or fail a job. Acceptance thresholds are set by Ali.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def _first(text: str, pattern: str) -> str | None:
    match = re.search(pattern, text, re.M)
    if match is None:
        return None
    return match.group(1)


def parse_meminfo(text: str) -> tuple[str, str]:
    """Return (pss_kb, rss_kb). Missing fields are the string `unavailable`."""
    pss = _first(text, r"TOTAL PSS:\s+(\d+)")
    rss = _first(text, r"TOTAL RSS:\s+(\d+)")
    if pss is None:
        # API 29 app summary prints PSS as `TOTAL:` and has no RSS column.
        pss = _first(text, r"^\s+TOTAL:\s+(\d+)\b")
    return (pss or "unavailable", rss or "unavailable")


def phase7_lines(when: str, text: str) -> list[str]:
    pss, rss = parse_meminfo(text)
    return [
        f"PHASE7 p7_24_meminfo_{when}_pss_kb={pss}",
        f"PHASE7 p7_24_meminfo_{when}_rss_kb={rss}",
        f"PHASE7 p7_24_meminfo_{when}_source=dumpsys-meminfo",
        "PHASE7 p7_24_meminfo_kind=report-only",
    ]


def self_test() -> None:
    api34 = """
App Summary
                       Pss(KB)                        Rss(KB)
                        ------                         ------
           Java Heap:    12340                          18000
           TOTAL PSS:    35052            TOTAL RSS:    52000       TOTAL SWAP (KB):        0
"""
    pss, rss = parse_meminfo(api34)
    assert pss == "35052", pss
    assert rss == "52000", rss

    api29 = """
App Summary
                       Pss(KB)
                        ------
           Java Heap:    12340
               TOTAL:    35040       TOTAL SWAP PSS:      120
"""
    pss, rss = parse_meminfo(api29)
    assert pss == "35040", pss
    assert rss == "unavailable", rss

    empty_pss, empty_rss = parse_meminfo("no process")
    assert empty_pss == "unavailable"
    assert empty_rss == "unavailable"
    lines = phase7_lines("before", api34)
    assert lines[0] == "PHASE7 p7_24_meminfo_before_pss_kb=35052"
    assert any("report-only" in line for line in lines)
    print("phase7_meminfo self-test ok")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--when", choices=("before", "after"))
    parser.add_argument("--file")
    args = parser.parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    if not args.when or not args.file:
        parser.error("--when and --file are required")
    text = Path(args.file).read_text(encoding="utf-8", errors="replace")
    for line in phase7_lines(args.when, text):
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
