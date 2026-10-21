#!/usr/bin/env python3
"""Fail if a release APK still contains fake-profile or demo-account strings.

Needles that live in the fake fixtures must still be present in that source
file, so renaming a fixture cannot make this scan pass by accident. The APK
is scanned after decompression, as raw bytes, UTF-8, and UTF-16LE (Dart AOT
stores many strings that way).

`--self-test` builds two tiny zips and does not need Flutter or an Android SDK.
"""

from __future__ import annotations

import sys
import tempfile
import zipfile
from pathlib import Path

# Identities compiled into the fake client. They must disappear from release.
FIXTURE_NEEDLES = (
    "admin@example.invalid",
    "employee@example.invalid",
    "limited.admin@example.invalid",
    "flag.admin@example.invalid",
    "guest@example.invalid",
    "mustchange@example.invalid",
    "مدير تجريبي",
    "موظف استلام تجريبي",
    "إداري محدود تجريبي",
    "إداري بعلم صريح",
    "دور غير معروف",
    "مستخدم تغيير كلمة المرور",
)

# Usernames and the shared demo password. They are test-only today. A release
# binary that gained them would be shipping a demo account.
DEMO_NEEDLES = (
    "demo-only",
    "admin.demo",
    "employee.demo",
    "limited.admin.demo",
    "flag.admin.demo",
    "guest.demo",
    "mustchange.demo",
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def encoded(text: str) -> tuple[tuple[str, bytes], ...]:
    return (
        (f"{text} utf-8", text.encode("utf-8")),
        (f"{text} utf-16le", text.encode("utf-16-le")),
    )


def all_needles() -> list[tuple[str, bytes]]:
    found: list[tuple[str, bytes]] = []
    for text in (*FIXTURE_NEEDLES, *DEMO_NEEDLES):
        found.extend(encoded(text))
    return found


def assert_fixtures_still_contain_needles(root: Path) -> None:
    source = root / "packages/api_layer/lib/data/fake/fake_fixtures.dart"
    text = source.read_text(encoding="utf-8")
    missing = [needle for needle in FIXTURE_NEEDLES if needle not in text]
    if missing:
        joined = ", ".join(missing)
        raise SystemExit(
            "scan needles missing from fake_fixtures.dart "
            f"(update the scan list with the fixture): {joined}"
        )


def scan_zip(path: Path, needles: list[tuple[str, bytes]]) -> list[str]:
    hits: list[str] = []
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            data = archive.read(info)
            for label, blob in needles:
                if blob in data:
                    hits.append(f"{info.filename}: {label}")
    return hits


def scan_apk(path: Path) -> list[str]:
    if not path.is_file():
        raise SystemExit(f"release APK not found: {path}")
    return scan_zip(path, all_needles())


def self_test() -> int:
    root = repo_root()
    assert_fixtures_still_contain_needles(root)
    needles = all_needles()
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        clean = _zip(directory / "clean.zip", {"lib/arm64-v8a/libapp.so": b"release-binary-without-fixtures"})
        dirty = _zip(
            directory / "dirty.zip",
            {"lib/arm64-v8a/libapp.so": "admin@example.invalid".encode("utf-8")},
        )
        if scan_zip(clean, needles):
            print("self-test: clean zip reported a hit", file=sys.stderr)
            return 1
        hits = scan_zip(dirty, needles)
        if not any("admin@example.invalid" in hit for hit in hits):
            print("self-test: dirty zip did not report the fixture email", file=sys.stderr)
            return 1
        arabic = "مدير تجريبي".encode("utf-16-le")
        arabic_zip = _zip(
            directory / "arabic.zip",
            {"lib/arm64-v8a/libapp.so": b"xx" + arabic + b"yy"},
        )
        if not scan_zip(arabic_zip, needles):
            print("self-test: UTF-16LE Arabic fixture was not found", file=sys.stderr)
            return 1
    print("scan_release_apk self-test ok")
    return 0


def _zip(path: Path, members: dict[str, bytes]) -> Path:
    with zipfile.ZipFile(path, "w") as archive:
        for name, data in members.items():
            archive.writestr(name, data)
    return path


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        return self_test()
    if len(sys.argv) != 2:
        print(
            "usage: scan_release_apk.py APK | scan_release_apk.py --self-test",
            file=sys.stderr,
        )
        return 2
    root = repo_root()
    assert_fixtures_still_contain_needles(root)
    hits = scan_apk(Path(sys.argv[1]))
    if hits:
        print("release APK contains fake profile or demo account strings:", file=sys.stderr)
        for hit in hits:
            print(f"- {hit}", file=sys.stderr)
        return 1
    print(f"release APK has no fake profile or demo account strings: {sys.argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
