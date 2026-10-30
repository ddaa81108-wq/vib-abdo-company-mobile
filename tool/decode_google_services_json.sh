#!/usr/bin/env bash
# Decode GOOGLE_SERVICES_JSON_BASE64 into android/app/google-services.json
# when that variable is non-empty. No-op otherwise. Never prints the secret.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${GOOGLE_SERVICES_JSON_BASE64//[[:space:]]/}" ]]; then
  echo "GOOGLE_SERVICES_JSON_BASE64 is not set. Firebase config will not be included."
  exit 0
fi

dest="android/app/google-services.json"
mkdir -p "$(dirname "$dest")"
tmp=$(mktemp)
if ! printf '%s' "$GOOGLE_SERVICES_JSON_BASE64" | tr -d '[:space:]' | base64 -d > "$tmp"; then
  rm -f "$tmp"
  echo "GOOGLE_SERVICES_JSON_BASE64 could not be decoded."
  exit 1
fi
mv "$tmp" "$dest"

python3 - "$dest" << 'PY'
import json
import sys
from pathlib import Path

dest = Path(sys.argv[1])
expected = "com.vip2100.vib"


def fail(message: str) -> None:
    dest.unlink(missing_ok=True)
    raise SystemExit(message)


try:
    data = json.loads(dest.read_text(encoding="utf-8"))
except json.JSONDecodeError:
    fail("GOOGLE_SERVICES_JSON_BASE64 did not decode to JSON. The file was removed.")

if not isinstance(data, dict) or "project_info" not in data or "client" not in data:
    fail(
        "Decoded google-services.json is missing project_info or client. "
        "The file was removed."
    )

clients = data.get("client")
if not isinstance(clients, list):
    fail("Decoded google-services.json client list is invalid. The file was removed.")

names: list[str] = []
for client in clients:
    if not isinstance(client, dict):
        continue
    info = client.get("client_info") or {}
    if not isinstance(info, dict):
        continue
    android = info.get("android_client_info") or {}
    if not isinstance(android, dict):
        continue
    name = android.get("package_name")
    if isinstance(name, str):
        names.append(name)

if expected not in names:
    found = ", ".join(names) if names else "(none)"
    fail(
        "google-services.json does not contain package "
        f"{expected}. Found: {found}. The file was removed."
    )

print(f"Decoded google-services.json for package {expected}.")
PY
