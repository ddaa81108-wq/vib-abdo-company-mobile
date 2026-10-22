#!/usr/bin/env python3
"""Turn PHASE7 key=value lines into a job summary.

Acceptance for P7-23 and P7-24 stays `recorded`. A workflow failure is an
engineering budget, not an invented Pass or Fail in the protocol template.
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
