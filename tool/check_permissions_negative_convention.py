#!/usr/bin/env python3
"""Fail if negative permission tests drift from the team convention.

A file is a negative permission test when its name ends with
`_permission_negative_test.dart` or it is a `*_test.dart` file under
`test/permissions/`. Each of those files must start the library with
`@Tags(['permissions-negative'])` and a `library;` directive. Any other test
file that uses the tag is also a failure. Both the app and
`packages/api_layer` must declare the tag in `dart_test.yaml` and must contain
at least one such test.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

TAG_NAME = "permissions-negative"
TAGS_CALL = re.compile(r"@Tags\s*\(\s*\[(?P<body>[\s\S]*?)\]\s*\)")
TAG_LITERAL = re.compile(r"""['"]permissions-negative['"]""")
LIBRARY = re.compile(r"(?m)^[ \t]*library[ \t]*;[ \t]*$")
TAG_KEY = re.compile(r"(?m)^[ \t]+permissions-negative:[ \t]*$")
TAGS_SECTION = re.compile(r"(?m)^tags:[ \t]*$")

ROOTS = (
    Path("test"),
    Path("packages/api_layer/test"),
)
CONFIGS = (
    Path("dart_test.yaml"),
    Path("packages/api_layer/dart_test.yaml"),
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def has_tag(text: str) -> bool:
    return any(TAG_LITERAL.search(match.group("body")) for match in TAGS_CALL.finditer(text))


def is_negative_test(path: Path) -> bool:
    rel = path.as_posix()
    if path.name.endswith("_permission_negative_test.dart"):
        return True
    return path.name.endswith("_test.dart") and "/test/permissions/" in f"/{rel}"


def check_config(root: Path, path: Path, errors: list[str]) -> None:
    file = root / path
    if not file.is_file():
        errors.append(f"missing {path}")
        return
    text = file.read_text(encoding="utf-8")
    if TAGS_SECTION.search(text) is None or TAG_KEY.search(text) is None:
        errors.append(
            f"{path} must declare tag `{TAG_NAME}` under `tags:` "
            "(see docs/TESTING.md)"
        )


def main() -> int:
    root = repo_root()
    errors: list[str] = []
    for config in CONFIGS:
        check_config(root, config, errors)

    found = {ROOTS[0].as_posix(): 0, ROOTS[1].as_posix(): 0}
    for test_root in ROOTS:
        base = root / test_root
        if not base.is_dir():
            errors.append(f"missing {test_root}")
            continue
        for path in sorted(base.rglob("*.dart")):
            text = path.read_text(encoding="utf-8")
            rel = path.relative_to(root).as_posix()
            tagged = has_tag(text)
            negative = is_negative_test(path.relative_to(root))
            if negative:
                found[test_root.as_posix()] += 1
                if not tagged:
                    errors.append(
                        f"{rel} is a negative permission test file but has no "
                        f"@Tags(['{TAG_NAME}'])"
                    )
                if LIBRARY.search(text) is None:
                    errors.append(
                        f"{rel} must include a `library;` directive so the tag "
                        "applies to the whole file"
                    )
            elif tagged:
                errors.append(
                    f"{rel} uses @{TAG_NAME} but is not named "
                    "*_permission_negative_test.dart and is not under test/permissions/"
                )

    for directory, count in found.items():
        if count == 0:
            errors.append(
                f"{directory} has no negative permission tests. "
                "The CI gate fails when the tag matches nothing."
            )

    if errors:
        print("permissions-negative convention check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        "permissions-negative convention ok: "
        + ", ".join(f"{count} in {name}" for name, count in found.items())
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
