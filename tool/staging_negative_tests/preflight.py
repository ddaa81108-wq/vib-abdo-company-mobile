#!/usr/bin/env python3
"""Decide whether the staging negative-permission workflow may call run.sh.

Prints status lines only. Never prints secret values.

  status=skip     a required secret is unset (exit 0)
  status=ready    required secrets are set and the origin is a staging/test host
  status=refuse   the origin looks like production, is not a staging origin,
                  or the optional limited-manager pair is only half set (exit 1)

Required names: STAGING_API_BASE, STAGING_ADMIN_USERNAME, STAGING_ADMIN_PASSWORD,
STAGING_EMPLOYEE_USERNAME, STAGING_EMPLOYEE_PASSWORD, STAGING_EMPLOYEE2_USERNAME,
STAGING_EMPLOYEE2_PASSWORD.

Optional pair (both or neither; pending DEF-002): STAGING_LIMITED_MANAGER_USERNAME,
STAGING_LIMITED_MANAGER_PASSWORD.

The origin must be https, have no userinfo, path, query, or fragment, and must
not be a placeholder. A DNS label other than the TLD must mark it as
staging or test (`staging`, `stage`, `test`, `testing`, or a label that
contains `staging` / starts or ends with those markers). A `prod`,
`production`, or `live` label refuses the run even if another label says
staging. The TLD does not count, so `api.company.test` is not a staging origin.
"""

from __future__ import annotations

import os
import sys
from urllib.parse import urlsplit

REQUIRED = (
    "STAGING_API_BASE",
    "STAGING_ADMIN_USERNAME",
    "STAGING_ADMIN_PASSWORD",
    "STAGING_EMPLOYEE_USERNAME",
    "STAGING_EMPLOYEE_PASSWORD",
    "STAGING_EMPLOYEE2_USERNAME",
    "STAGING_EMPLOYEE2_PASSWORD",
)

OPTIONAL_USER = "STAGING_LIMITED_MANAGER_USERNAME"
OPTIONAL_PASSWORD = "STAGING_LIMITED_MANAGER_PASSWORD"


def _value(env: dict[str, str], name: str) -> str:
    return env.get(name, "").strip()


def _prod_label(label: str) -> bool:
    if label in {"prod", "production", "live"}:
        return True
    if "production" in label:
        return True
    return label.startswith(("prod-", "production-", "live-")) or label.endswith(
        ("-prod", "-production", "-live")
    )


def _staging_label(label: str) -> bool:
    if label in {"staging", "stage", "test", "testing"}:
        return True
    if "staging" in label or "testing" in label:
        return True
    return (
        label.startswith(("stage-", "test-"))
        or label.endswith(("-stage", "-test"))
    )


def _placeholder(host: str) -> bool:
    if host in {"example.com", "example.org", "example.net", "localhost"}:
        return True
    if host.endswith((".example", ".invalid", ".example.com", ".localhost")):
        return True
    return any(word in host for word in ("placeholder", "changeme", "replace-me", "replace_me"))


def classify_origin(url: str) -> str:
    """Return `ok`, `prod`, or `not-staging`. Does not include the URL."""
    parts = urlsplit(url.strip())
    host = (parts.hostname or "").lower().rstrip(".")
    labels = [label for label in host.split(".") if label]
    if labels and any(_prod_label(label) for label in labels):
        return "prod"
    if parts.scheme != "https":
        return "not-staging"
    if parts.username or parts.password:
        return "not-staging"
    if parts.query or parts.fragment:
        return "not-staging"
    if parts.path not in ("", "/"):
        return "not-staging"
    if not host or _placeholder(host) or not labels:
        return "not-staging"
    # The final label is the TLD (`test`, `com`). It does not count as a
    # staging marker, so `api.company.test` is not a staging origin.
    markers = labels[:-1]
    if any(_staging_label(label) for label in markers):
        return "ok"
    return "not-staging"


def evaluate(env: dict[str, str]) -> tuple[int, list[str]]:
    missing = [name for name in REQUIRED if not _value(env, name)]
    if missing:
        return 0, [f"status=skip", f"missing={','.join(missing)}"]

    user = _value(env, OPTIONAL_USER)
    password = _value(env, OPTIONAL_PASSWORD)
    if bool(user) != bool(password):
        return 1, [
            "status=refuse",
            "reason=partial-optional-secret",
            f"partial={OPTIONAL_USER},{OPTIONAL_PASSWORD}",
        ]

    kind = classify_origin(_value(env, "STAGING_API_BASE"))
    if kind == "prod":
        return 1, ["status=refuse", "reason=looks-like-production"]
    if kind != "ok":
        return 1, ["status=refuse", "reason=not-staging-origin"]

    limited = "present" if user and password else "absent"
    return 0, ["status=ready", f"limited_manager={limited}"]


def main() -> int:
    code, lines = evaluate(dict(os.environ))
    for line in lines:
        print(line)
    if code != 0:
        print(
            "Refusing to run staging negative tests. "
            "The origin was not printed.",
            file=sys.stderr,
        )
    return code


if __name__ == "__main__":
    sys.exit(main())
