#!/usr/bin/env python3
"""Append a short GitHub Actions job summary for analyze, test, and the APK.

Reads log files produced by the workflow. Uses only the standard library.
"""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path

# Last progress line from `flutter test --reporter expanded`.
# Examples: "00:04 +46: All tests passed!" and "01:02 +12 ~1 -2: Some tests failed."
_TEST_PROGRESS = re.compile(
    r"(?:^|\n)[0-9:]+ \+(?P<passed>\d+)(?: ~(?P<skipped>\d+))?(?: -(?P<failed>\d+))?:"
)
_TEST_FAILURE = re.compile(r"^.* \[E\]\s*$", re.MULTILINE)
_TEST_FAILURE_PREFIX = re.compile(r"^[0-9:]+ \+\d+(?: ~\d+)?(?: -\d+)?: ")
_ANALYZE_CLEAN = re.compile(r"No issues found!")
_ANALYZE_COUNT = re.compile(r"(\d+) issues? found")
_ANALYZE_ISSUE = re.compile(r"^(?:error|warning|info) • .*$", re.MULTILINE)


def _read(path: str | None) -> str:
    if not path:
        return ""
    file = Path(path)
    if not file.is_file():
        return ""
    return file.read_text(encoding="utf-8", errors="replace")


def _outcome_label(outcome: str) -> str:
    if outcome == "success":
        return "passed"
    if outcome == "failure":
        return "failed"
    if outcome == "skipped":
        return "skipped"
    return outcome or "unknown"


def _summarize_analyze(log: str) -> str:
    if not log.strip():
        return "no log"
    if _ANALYZE_CLEAN.search(log):
        return "no issues"
    count = _ANALYZE_COUNT.search(log)
    issues = _ANALYZE_ISSUE.findall(log)
    detail = f"{count.group(1)} issues" if count else "issues reported"
    if issues:
        preview = "; ".join(issues[:5])
        if len(issues) > 5:
            preview += f"; +{len(issues) - 5} more"
        return f"{detail}: {preview}"
    return detail


def _summarize_tests(log: str) -> str:
    if not log.strip():
        return "no log"
    matches = list(_TEST_PROGRESS.finditer(log))
    if not matches:
        return "could not parse the test reporter output"
    last = matches[-1]
    passed = int(last.group("passed"))
    skipped = int(last.group("skipped") or 0)
    failed = int(last.group("failed") or 0)
    parts = [f"{passed} passed"]
    if skipped:
        parts.append(f"{skipped} skipped")
    if failed:
        parts.append(f"{failed} failed")
    failures = _TEST_FAILURE.findall(log)
    if failures:
        names = [_TEST_FAILURE_PREFIX.sub("", line.strip()) for line in failures[:8]]
        extra = f"; +{len(failures) - 8} more" if len(failures) > 8 else ""
        parts.append("failed tests: " + " | ".join(names) + extra)
    return ", ".join(parts)


def _append(markdown: str) -> None:
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary:
        print(markdown)
        return
    with open(summary, "a", encoding="utf-8") as handle:
        handle.write(markdown)
        if not markdown.endswith("\n"):
            handle.write("\n")


def write_checks(args: argparse.Namespace) -> None:
    rows = [
        ("App analyze", args.analyze_app_outcome, _summarize_analyze(_read(args.analyze_app_log))),
        (
            "API package analyze",
            args.analyze_api_outcome,
            _summarize_analyze(_read(args.analyze_api_log)),
        ),
        ("App tests", args.test_app_outcome, _summarize_tests(_read(args.test_app_log))),
        (
            "API package tests",
            args.test_api_outcome,
            _summarize_tests(_read(args.test_api_log)),
        ),
    ]
    lines = [
        "## CI summary",
        "",
        "Fake API only. `USE_FAKE_API` defaults to true and is passed explicitly on tests and the APK build. No secrets and no real API host are configured.",
        "",
        "| Check | Result | Detail |",
        "| --- | --- | --- |",
    ]
    for name, outcome, detail in rows:
        safe_detail = detail.replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {name} | {_outcome_label(outcome)} | {safe_detail} |")
    lines.append("")
    _append("\n".join(lines) + "\n")


def write_apk(args: argparse.Namespace) -> None:
    apk = Path(args.apk)
    if not apk.is_file():
        raise SystemExit(f"APK not found: {apk}")
    size = apk.stat().st_size
    mebibytes = size / (1024 * 1024)
    _append(
        "\n".join(
            [
                "### Debug APK",
                "",
                f"- File: `{apk.as_posix()}`",
                f"- Size: {mebibytes:.1f} MiB ({size} bytes)",
                "- Build: `flutter build apk --debug --dart-define=USE_FAKE_API=true`",
                "- Signing: debug keystore (unchanged). Application id: `com.example.vib_abdo_company_mobile`.",
                "- Artifact name: `app-debug-apk`. On the workflow run, open **Artifacts** and download that zip. It contains this APK.",
                "",
            ]
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    checks = sub.add_parser("checks")
    checks.add_argument("--analyze-app-outcome", default="skipped")
    checks.add_argument("--analyze-api-outcome", default="skipped")
    checks.add_argument("--test-app-outcome", default="skipped")
    checks.add_argument("--test-api-outcome", default="skipped")
    checks.add_argument("--analyze-app-log")
    checks.add_argument("--analyze-api-log")
    checks.add_argument("--test-app-log")
    checks.add_argument("--test-api-log")
    checks.set_defaults(func=write_checks)

    apk = sub.add_parser("apk")
    apk.add_argument("--apk", required=True)
    apk.set_defaults(func=write_apk)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
