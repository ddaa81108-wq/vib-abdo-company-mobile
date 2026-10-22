#!/usr/bin/env python3
"""Turn PHASE7 key=value lines into a job summary.

Acceptance for P7-23 and P7-24 stays `recorded`. Numeric budgets in the
summary are engineering proposals. Acceptance thresholds are set by Ali.
RSS, PSS, and Dart heap lines are report-only.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def parse_lines(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        marker = "PHASE7 "
        index = line.find(marker)
        if index < 0:
            continue
        body = line[index + len(marker) :]
        if "=" not in body:
            continue
        key, value = body.split("=", 1)
        found[key.strip()] = value.strip()
    return found


PROPOSAL_BANNER = """\
Engineering proposals, not acceptance thresholds. Acceptance thresholds are set by Ali.

| Proposal | Number | Role |
|---|---|---|
| Device cold start (`am start -W` TotalTime) | 5000 ms | engineering proposal |
| Emulator cold start hang | 20000 ms | engineering proposal |
| Login to home on staging | 60000 ms | engineering proposal |
| Device worst frame build | 32 ms | engineering proposal |
| Device average frame build | 16.7 ms | engineering proposal |
| Widget history walk | 8 s | engineering proposal |

A workflow failure on one of these numbers is not a protocol Pass or Fail. RSS, PSS, and Dart heap are report-only. They are not budgets and they do not pass or fail the job.
"""


def markdown(title: str, values: dict[str, str]) -> str:
    rows = [
        "| device | OS/API | build SHA | tester | date | step | expected | actual | pass/fail | screenshot ref | defect id |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    interesting = [
        ("P7-23", "p7_23_total_time_ms", "process TotalTime ms"),
        ("P7-23", "p7_23_home_ms", "scripted home ms"),
        ("P7-24", "p7_24_worst_build_ms", "worst build ms"),
        ("P7-24", "p7_24_average_build_ms", "average build ms"),
        ("P7-24", "p7_24_meminfo_before_pss_kb", "PSS KB before scroll (report-only)"),
        ("P7-24", "p7_24_meminfo_after_pss_kb", "PSS KB after scroll (report-only)"),
        ("P7-24", "p7_24_meminfo_before_rss_kb", "RSS KB before scroll (report-only)"),
        ("P7-24", "p7_24_meminfo_after_rss_kb", "RSS KB after scroll (report-only)"),
        ("P7-24", "p7_24_dart_heap_before_bytes", "Dart heap bytes before scroll (report-only)"),
        ("P7-24", "p7_24_dart_heap_after_bytes", "Dart heap bytes after scroll (report-only)"),
        ("P7-25", "p7_25_pages_loaded", "ledger pages loaded"),
    ]
    for step, key, label in interesting:
        if key not in values:
            continue
        rows.append(
            f"| | | | ci | | {step} {label} | record the number | {values[key]} | recorded | | |"
        )
    if len(rows) == 2:
        rows.append("| | | | | | | | | recorded | | |")

    measured = "\n".join(f"- `{key}` = `{value}`" for key, value in sorted(values.items()))
    if not measured:
        measured = "- no PHASE7 lines in this log"
    coverage = "\n".join(
        [
            "| ID | This job |",
            "|---|---|",
            "| P7-23 | Release cold start. Numbers only. Not Pass. |",
            "| P7-24 | Long-ledger frame timings. Numbers only. Not Pass. |",
            "| P7-25 | Page walk through the real load-older control. |",
            "| P7-26 | Emulator API from the matrix, plus the manual device form. |",
        ]
    )
    return "\n".join(
        [
            f"### {title}",
            "",
            PROPOSAL_BANNER.rstrip(),
            "",
            "Phase 7 matrix: https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/48",
            "(`docs/acceptance/phase-7.md`, not merged into this branch).",
            "",
            coverage,
            "",
            "Measured lines:",
            "",
            measured,
            "",
            "Result template (acceptance column stays `recorded`):",
            "",
            *rows,
            "",
            "Pass/Fail/Blocked/Not supported is filled by the tester after Ali writes the numeric threshold. Do not copy an engineering budget into that column.",
            "",
        ]
    )


def self_test() -> None:
    sample = "noise\nPHASE7 p7_23_total_time_ms=1200\nPHASE7 p7_24_worst_build_ms=11\n"
    values = parse_lines(sample)
    assert values["p7_23_total_time_ms"] == "1200"
    text = markdown("sample", values)
    assert "recorded" in text
    assert "P7-23" in text
    assert "Pass |" not in text
    assert "Engineering proposals, not acceptance thresholds." in text
    assert "Acceptance thresholds are set by Ali." in text
    for needle in ("5000 ms", "20000 ms", "60000 ms", "32 ms", "16.7 ms", "8 s"):
        assert needle in text, needle
    assert "report-only" in text
    memory = markdown(
        "memory",
        {
            "p7_24_meminfo_before_pss_kb": "12000",
            "p7_24_meminfo_after_pss_kb": "13000",
            "p7_24_dart_heap_before_bytes": "4000000",
            "p7_24_dart_heap_after_bytes": "5000000",
        },
    )
    assert "12000" in memory
    assert "PSS KB before scroll (report-only)" in memory
    assert "Dart heap bytes after scroll (report-only)" in memory
    print("phase7_summary self-test ok")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--title", default="Phase 7 performance")
    parser.add_argument("--log")
    parser.add_argument("--out")
    parser.add_argument("--summary", help="Append markdown to this file, usually $GITHUB_STEP_SUMMARY")
    args = parser.parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    text = ""
    if args.log:
        path = Path(args.log)
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
    body = markdown(args.title, parse_lines(text))
    print(body)
    if args.out:
        Path(args.out).write_text(body, encoding="utf-8")
    if args.summary:
        with Path(args.summary).open("a", encoding="utf-8") as handle:
            handle.write(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
