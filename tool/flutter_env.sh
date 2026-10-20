#!/usr/bin/env bash
# Run or build with one named dart-define file.
#
# Usage:
#   tool/flutter_env.sh <fake|staging|prod> <flutter-args...>
#
# Examples:
#   tool/flutter_env.sh fake run
#   tool/flutter_env.sh fake build apk --debug
#   tool/flutter_env.sh staging build apk --debug
#
# fake    uses config/dart_defines/fake.json when that gitignored file exists,
#         otherwise the committed config/dart_defines/fake.example.json.
# staging requires the gitignored config/dart_defines/staging.json.
# prod    is a placeholder and is always refused.
#
# See docs/ENVIRONMENTS.md.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

usage() {
  cat <<'EOF'
usage: tool/flutter_env.sh <fake|staging|prod> <flutter-args...>

  fake      in-memory client, no network (default app behavior)
  staging   real client pointed at a staging or test origin
  prod      reserved placeholder; this command always refuses it

The flutter-args are the arguments you would pass to flutter, for example:
  run
  run -d emulator-5554
  build apk --debug

Extra --dart-define flags are forwarded. Flutter gives them precedence over the file.
The script appends --dart-define-from-file after those arguments.
Flutter 3.47 accepts that flag on the subcommand (run, test, build apk), not before the subcommand.
EOF
}

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  if [[ $# -ge 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
    exit 0
  fi
  exit 2
fi

env_name="$1"
shift

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

defines_dir="$root/config/dart_defines"

case "$env_name" in
  fake)
    if [[ -f "$defines_dir/fake.json" ]]; then
      defines_file="$defines_dir/fake.json"
    else
      defines_file="$defines_dir/fake.example.json"
    fi
    ;;
  staging)
    defines_file="$defines_dir/staging.json"
    if [[ ! -f "$defines_file" ]]; then
      echo "Missing config/dart_defines/staging.json" >&2
      echo "Copy the example and set API_BASE to the staging origin from the server owner:" >&2
      echo "  cp config/dart_defines/staging.example.json config/dart_defines/staging.json" >&2
      echo "Do not commit that file." >&2
      exit 1
    fi
    ;;
  prod)
    echo "prod is a placeholder only. This app may target a staging or test copy, not production." >&2
    echo "tool/flutter_env.sh will not build or run prod. See docs/ENVIRONMENTS.md." >&2
    exit 1
    ;;
  *)
    echo "Unknown environment: $env_name (expected fake, staging, or prod)" >&2
    usage
    exit 2
    ;;
esac

python3 - "$env_name" "$defines_file" <<'PY'
import json
import sys
from urllib.parse import urlparse

env_name, path = sys.argv[1], sys.argv[2]
known = (
    "USE_FAKE_API",
    "API_BASE",
    "API_DEBUG_LOG",
    "AUTH_BEARER",
    "MONEY_UNIT_SCALE",
    "RATE_WIRE_FORMAT",
)

def fail(messages):
    print(f"{path} is not a valid {env_name} define file:", file=sys.stderr)
    for message in messages:
        print(f"  - {message}", file=sys.stderr)
    sys.exit(1)

try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, json.JSONDecodeError) as error:
    fail([f"could not read JSON ({error})"])

errors = []
if not isinstance(data, dict):
    fail(["the file must be a JSON object"])

unknown = sorted(set(data) - set(known))
missing = [key for key in known if key not in data]
if unknown:
    errors.append("unknown keys (ApiConfig does not read them): " + ", ".join(unknown))
if missing:
    errors.append("missing keys: " + ", ".join(missing))

def as_bool(key):
    value = data.get(key)
    if isinstance(value, bool):
        return value
    if value in ("true", "false"):
        return value == "true"
    errors.append(f"{key} must be a JSON boolean (or the string \"true\" or \"false\")")
    return None

use_fake = as_bool("USE_FAKE_API")
as_bool("API_DEBUG_LOG")
as_bool("AUTH_BEARER")

scale = data.get("MONEY_UNIT_SCALE")
if isinstance(scale, bool) or not isinstance(scale, int):
    if isinstance(scale, str) and scale.isascii() and scale.isdigit():
        scale = int(scale)
    else:
        errors.append("MONEY_UNIT_SCALE must be a non-negative integer")
        scale = None
if isinstance(scale, int) and scale < 0:
    errors.append("MONEY_UNIT_SCALE must be a non-negative integer")

wire = data.get("RATE_WIRE_FORMAT")
if wire not in ("number", "string"):
    errors.append('RATE_WIRE_FORMAT must be "number" or "string"')

base = data.get("API_BASE")
if not isinstance(base, str) or not base.strip():
    errors.append("API_BASE must be a non-empty string")
else:
    parsed = urlparse(base.strip())
    host = (parsed.hostname or "").lower()
    placeholder = (
        host.endswith(".invalid")
        or host.endswith(".example")
        or host == "example.com"
        or host.endswith(".example.com")
        or "placeholder" in base.lower()
        or "changeme" in base.lower()
        or "replace" in base.lower()
    )
    if env_name == "staging":
        if parsed.scheme.lower() not in ("https", "http"):
            errors.append("API_BASE must be an absolute http or https origin")
        elif parsed.username or parsed.password or parsed.query or parsed.fragment:
            errors.append("API_BASE must be an origin only (no user, query, or fragment)")
        elif parsed.path not in ("", "/"):
            errors.append("API_BASE must be an origin only. Paths in the app already start with /api")
        elif not host:
            errors.append("API_BASE must include a host")
        elif placeholder:
            errors.append(
                "API_BASE is still a placeholder. Set the staging or test origin supplied outside this repo"
            )
    elif placeholder and use_fake is False:
        errors.append("a non-fake file must not keep a placeholder API_BASE")

if env_name == "fake" and use_fake is False:
    errors.append("fake must set USE_FAKE_API to true. Use the staging environment for a real server")
if env_name == "staging" and use_fake is not False:
    errors.append("staging must set USE_FAKE_API to false")

if errors:
    fail(errors)
PY

rel="${defines_file#"$root"/}"
echo "Environment: $env_name"
echo "dart-define file: $rel"

# Flutter 3.47 accepts --dart-define-from-file on the subcommand only.
# Command-line --dart-define still overrides the same key from the file.
exec flutter "$@" --dart-define-from-file="$defines_file"
