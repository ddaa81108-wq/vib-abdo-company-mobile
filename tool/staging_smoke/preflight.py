#!/usr/bin/env python3
"""Origin check for the P-01 staging smoke.

Prints status lines only. Never prints the configured origin or credentials.

This module does not perform HTTP. ``urllib.parse`` only splits the origin.
Reachability is ``curl`` in ``reachability.sh`` with an explicit User-Agent.
Do not add ``urllib.request``, ``http.client``, or ``requests`` here.

  status=ok
  status=fail
  reason=empty|erp-suffix|looks-like-production|not-staging-origin

``STAGING_API_BASE`` must be the origin ``https://staging.vip2100.com`` with
no ``/erp`` suffix. An empty value fails. It is not replaced with a default.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import sys
from pathlib import Path
from urllib.parse import urlsplit

INTENDED_ORIGIN = "https://staging.vip2100.com"

MASK_NAMES = (
    "STAGING_API_BASE",
    "STAGING_ADMIN_USERNAME",
    "STAGING_ADMIN_PASSWORD",
    "STAGING_EMPLOYEE_USERNAME",
    "STAGING_EMPLOYEE_PASSWORD",
    "STAGING_EMPLOYEE2_USERNAME",
    "STAGING_EMPLOYEE2_PASSWORD",
    "STAGING_LIMITED_MANAGER_USERNAME",
    "STAGING_LIMITED_MANAGER_PASSWORD",
    "STAGING_SMOKE_ACCOUNT_ID",
    "STAGING_SMOKE_SECTION",
)

ADMIN_NAMES = (
    "STAGING_ADMIN_USERNAME",
    "STAGING_ADMIN_PASSWORD",
)

REASONS = {
    "empty": (
        "STAGING_API_BASE is empty. Set the staging origin on the staging "
        f"environment (secret or variable STAGING_API_BASE). The intended "
        f"value is {INTENDED_ORIGIN} with no /erp suffix. The configured "
        "value was not printed."
    ),
    "erp-suffix": (
        "STAGING_API_BASE must not end with /erp. The intended value is "
        f"{INTENDED_ORIGIN} with no /erp suffix. The site UI lives under "
        "/erp and the API lives at /api on the origin. The configured "
        "value was not printed."
    ),
    "looks-like-production": (
        "STAGING_API_BASE looks like production and was refused. "
        "The value was not printed."
    ),
    "not-staging-origin": (
        "STAGING_API_BASE is not a staging origin. It must be https, with "
        "no userinfo, path, query, or fragment, and a staging or test DNS "
        "label. The value was not printed."
    ),
}


def _classify_origin():
    path = (
        Path(__file__).resolve().parents[1]
        / "staging_negative_tests"
        / "preflight.py"
    )
    spec = importlib.util.spec_from_file_location(
        "staging_negative_preflight", path
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("staging origin classifier is missing")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.classify_origin


classify_origin = _classify_origin()


def _present(value: str) -> bool:
    return bool(value.strip())


def has_erp_suffix(url: str) -> bool:
    """True when the path is /erp or the URL ends with /erp."""
    stripped = url.strip()
    if not stripped:
        return False
    parts = urlsplit(stripped)
    path = (parts.path or "").rstrip("/")
    lowered = path.lower()
    if lowered == "/erp" or lowered.startswith("/erp/"):
        return True
    return stripped.rstrip("/").lower().endswith("/erp")


def normalized_origin(url: str) -> str:
    parts = urlsplit(url.strip())
    host = parts.hostname or ""
    if ":" in host and not host.startswith("["):
        host = f"[{host}]"
    port = f":{parts.port}" if parts.port else ""
    return f"{parts.scheme}://{host}{port}"


def decide(raw: str) -> tuple[bool, str, str]:
    """Return (ok, reason, origin). Origin is empty unless ok."""
    value = (raw or "").strip()
    if not value:
        return False, "empty", ""
    if has_erp_suffix(value):
        return False, "erp-suffix", ""
    kind = classify_origin(value)
    if kind == "prod":
        return False, "looks-like-production", ""
    if kind != "ok":
        return False, "not-staging-origin", ""
    return True, "", normalized_origin(value)


def _mask_line(value: str) -> None:
    if value:
        print(f"::add-mask::{value}", flush=True)


def mask_env(env: dict[str, str]) -> None:
    for name in MASK_NAMES:
        raw = env.get(name, "")
        if not raw:
            continue
        collapsed = raw.replace("\n", "").replace("\r", "")
        _mask_line(collapsed)
        stripped = collapsed.strip()
        if stripped and stripped != collapsed:
            _mask_line(stripped)
        if name != "STAGING_API_BASE" or not stripped:
            continue
        origin = stripped.rstrip("/")
        if origin and origin != stripped:
            _mask_line(origin)
        if origin:
            _mask_line(origin + "/api/health")


def auth_lines(env: dict[str, str]) -> list[str]:
    missing = [name for name in ADMIN_NAMES if not _present(env.get(name, ""))]
    if missing:
        return [
            "configured=false",
            "missing=" + ",".join(missing),
        ]
    return ["configured=true", "missing="]


def _summary(title: str, lines: list[str]) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"### {title}\n\n")
        for line in lines:
            handle.write(f"{line}\n")
        handle.write("\nThe configured value was not printed.\n")


def _emit_decision(ok: bool, reason: str, *, quiet: bool) -> None:
    if ok:
        print("status=ok")
        if not quiet:
            _summary(
                "Staging origin check",
                [
                    "status=ok",
                    f"Intended origin: `{INTENDED_ORIGIN}` (no `/erp` suffix).",
                ],
            )
        return
    print("status=fail")
    print(f"reason={reason}")
    message = REASONS[reason]
    print(message, file=sys.stderr)
    print(f"::error title=Staging origin refused::{message}")
    if not quiet:
        _summary("Staging origin check", [f"status=fail", f"reason={reason}", message])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mask", action="store_true")
    parser.add_argument("--auth-status", action="store_true")
    parser.add_argument("--export-origin", metavar="PATH")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    modes = sum(
        bool(item)
        for item in (args.mask, args.auth_status, args.export_origin)
    )
    if modes > 1:
        parser.error("choose only one of --mask, --auth-status, --export-origin")

    env = dict(os.environ)
    if args.mask:
        if env.get("GITHUB_ACTIONS") == "true":
            mask_env(env)
        return 0
    if args.auth_status:
        for line in auth_lines(env):
            print(line)
        return 0

    ok, reason, origin = decide(env.get("STAGING_API_BASE", ""))
    _emit_decision(ok, reason, quiet=args.quiet)
    if not ok:
        return 1
    if args.export_origin:
        path = Path(args.export_origin)
        path.write_text(origin + "\n", encoding="utf-8")
        path.chmod(0o600)
    return 0


if __name__ == "__main__":
    sys.exit(main())
