#!/usr/bin/env python3
"""Release APK size budget for the Phase 7 performance workflow.

Warn at 64 MiB. Fail at 72 MiB. The prior fat release APK was about 58.9 MiB.

The size build uses https://staging.example.com. That origin fails
classify_origin (placeholder). It is not the protocol install. Do not treat
a green size job as P7-23 or P7-26 Pass.

Keep the byte limits in sync with lib/performance/perf_budget.dart.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

WARN_BYTES = 64 * 1024 * 1024
FAIL_BYTES = 72 * 1024 * 1024
BASELINE_MIB = 58.9


def judge(size: int) -> str:
    if size > FAIL_BYTES:
        return "fail"
    if size > WARN_BYTES:
        return "warn"
    return "ok"


def report(size: int, apk: str) -> dict[str, object]:
    status = judge(size)
    return {
        "apk": apk,
        "bytes": size,
        "mebibytes": round(size / (1024 * 1024), 2),
        "warnBytes": WARN_BYTES,
        "failBytes": FAIL_BYTES,
        "baselineMebibytes": BASELINE_MIB,
        "status": status,
        "protocolInstall": False,
        "note": (
            "Size build uses https://staging.example.com. "
            "Not the P7-26 protocol install. Not an acceptance Pass."
        ),
    }


def markdown(data: dict[str, object]) -> str:
    lines = [
        "### P7 APK size",
        "",
        f"- Status: `{data['status']}`",
        f"- Size: {data['mebibytes']} MiB ({data['bytes']} bytes)",
        f"- Warn above {WARN_BYTES} bytes (64 MiB)",
        f"- Fail above {FAIL_BYTES} bytes (72 MiB)",
        f"- Baseline comment: {BASELINE_MIB} MiB",
        f"- {data['note']}",
        "",
        "P7-23 and P7-26 acceptance stay recorded. This job does not mark Pass.",
        "",
    ]
    return "\n".join(lines)


def self_test() -> None:
    assert judge(60 * 1024 * 1024) == "ok"
    assert judge(WARN_BYTES) == "ok"
    assert judge(WARN_BYTES + 1) == "warn"
    assert judge(FAIL_BYTES) == "warn"
    assert judge(FAIL_BYTES + 1) == "fail"
    sample = report(58 * 1024 * 1024, "sample.apk")
    text = markdown(sample)
    assert "P7 APK size" in text
    assert sample["protocolInstall"] is False
    print("apk_size_budget self-test ok")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--apk")
    parser.add_argument("--out")
    parser.add_argument("--json-out")
    args = parser.parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    if not args.apk:
        parser.error("--apk is required unless --self-test")
    path = Path(args.apk)
    if not path.is_file():
        print(f"APK not found: {path}", file=sys.stderr)
        return 1
    data = report(path.stat().st_size, str(path))
    text = markdown(data)
    print(text)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(data, indent=2) + "\n",
            encoding="utf-8",
        )
    if data["status"] == "fail":
        print("APK size exceeded the fail budget.", file=sys.stderr)
        return 1
    if data["status"] == "warn":
        print("APK size exceeded the warn budget.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
