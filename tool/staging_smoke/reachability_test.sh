#!/usr/bin/env bash
# Offline checks for the P-01 smoke scripts. Placeholders only. No network.
set -euo pipefail
cd "$(dirname "$0")/../.."

ROOT="$PWD"
PREFLIGHT="tool/staging_smoke/preflight.py"
REACH="tool/staging_smoke/reachability.sh"
WORKFLOW=".github/workflows/staging-smoke.yml"

if grep -E '^[[:space:]]*(import|from)[[:space:]]+(urllib\.request|http\.client|requests|socket)\b|^[[:space:]]*import[[:space:]]+urllib\.request|^[[:space:]]*from[[:space:]]+urllib[[:space:]]+import[[:space:]]+request' "$PREFLIGHT"; then
  echo "preflight must not perform HTTP"
  exit 1
fi

# Env assignments, then the python command. Example:
# pf STAGING_API_BASE=https://staging.company.test python3 "$PREFLIGHT"
pf() {
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" "$@"
}

expect_reason() {
  local want="$1"
  shift
  local out err code
  set +e
  out="$(pf "$@" 2>/tmp/smoke-preflight.err)"
  code=$?
  set -e
  err="$(cat /tmp/smoke-preflight.err)"
  rm -f /tmp/smoke-preflight.err
  if [[ "$code" -eq 0 ]]; then
    echo "expected failure reason=$want"
    printf '%s\n' "$out"
    exit 1
  fi
  if ! printf '%s\n' "$out" | grep -qx "reason=${want}"; then
    echo "expected reason=$want"
    printf '%s\n' "$out"
    printf '%s\n' "$err"
    exit 1
  fi
  printf '%s\n%s\n' "$out" "$err"
}

echo "== workflow is dispatch only =="
python3 - "$WORKFLOW" << 'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for raw in text.splitlines():
    line = raw.split("#", 1)[0].rstrip()
    if re.match(r"\s*(push|pull_request|schedule|workflow_call|workflow_run|repository_dispatch):", line):
        sys.exit(f"forbidden trigger: {line}")
if "workflow_dispatch:" not in text:
    sys.exit("missing workflow_dispatch")
if "environment: staging" not in text:
    sys.exit("job must set environment: staging")
if "secrets.STAGING_SMOKE_ACCOUNT_ID" in text or "vars.STAGING_SMOKE_ACCOUNT_ID" in text:
    sys.exit("workflow must not read STAGING_SMOKE_ACCOUNT_ID")
for needle in ("secrets.STAGING_API_BASE", "vars.STAGING_API_BASE"):
    if needle not in text:
        sys.exit(f"missing {needle}")
banned = (
    "STAGING_ADMIN_USERNAME",
    "STAGING_ADMIN_PASSWORD",
    "STAGING_EMPLOYEE_USERNAME",
    "STAGING_EMPLOYEE_PASSWORD",
    "STAGING_EMPLOYEE2_USERNAME",
    "STAGING_EMPLOYEE2_PASSWORD",
    "STAGING_LIMITED_MANAGER_USERNAME",
    "STAGING_LIMITED_MANAGER_PASSWORD",
    "flutter-action",
    "flutter test",
)
for needle in banned:
    if needle in text:
        sys.exit(f"workflow must not mention {needle}")
uses = re.findall(r"uses:\s*(\S+)", text)
if not uses:
    sys.exit("workflow has no actions")
for use in uses:
    if not re.search(r"@[0-9a-f]{40}$", use):
        sys.exit(f"action is not pinned to a full commit SHA: {use}")
checkout = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"
if checkout not in text:
    sys.exit("checkout is not pinned to the v7.0.1 commit")
print("workflow shape ok")
PY

echo "== empty base fails =="
out="$(expect_reason empty python3 "$PREFLIGHT")"
printf '%s\n' "$out" | grep -q 'STAGING_API_BASE is empty'
printf '%s\n' "$out" | grep -q 'https://staging.vip2100.com'

echo "== whitespace base fails =="
expect_reason empty STAGING_API_BASE='   ' python3 "$PREFLIGHT" >/dev/null

echo "== /erp suffix fails and does not echo the host =="
out="$(expect_reason erp-suffix STAGING_API_BASE='https://staging.secret-host.test/erp' python3 "$PREFLIGHT")"
printf '%s\n' "$out" | grep -q 'must not end with /erp'
if printf '%s\n' "$out" | grep -q 'secret-host'; then
  echo "erp failure printed the configured host"
  exit 1
fi
expect_reason erp-suffix STAGING_API_BASE='https://staging.secret-host.test/erp/' python3 "$PREFLIGHT" >/dev/null
expect_reason erp-suffix STAGING_API_BASE='https://staging.secret-host.test/ERP' python3 "$PREFLIGHT" >/dev/null
expect_reason erp-suffix STAGING_API_BASE='https://staging.secret-host.test/erp/api' python3 "$PREFLIGHT" >/dev/null

echo "== production and non-staging fail closed =="
out="$(expect_reason looks-like-production STAGING_API_BASE='https://prod.secret-host.test' python3 "$PREFLIGHT")"
if printf '%s\n' "$out" | grep -q 'secret-host'; then
  echo "production failure printed the configured host"
  exit 1
fi
out="$(expect_reason not-staging-origin STAGING_API_BASE='https://user:secret-pass@staging.company.test' python3 "$PREFLIGHT")"
if printf '%s\n' "$out" | grep -q 'secret-pass'; then
  echo "userinfo was printed"
  exit 1
fi
expect_reason not-staging-origin STAGING_API_BASE='https://api.company.test' python3 "$PREFLIGHT" >/dev/null
expect_reason not-staging-origin STAGING_API_BASE='http://staging.company.test' python3 "$PREFLIGHT" >/dev/null
expect_reason not-staging-origin STAGING_API_BASE='https://staging.company.test/api' python3 "$PREFLIGHT" >/dev/null

echo "== intended origin shape is accepted =="
out="$(pf STAGING_API_BASE='https://staging.vip2100.com' python3 "$PREFLIGHT")"
printf '%s\n' "$out" | grep -qx 'status=ok'
out="$(pf STAGING_API_BASE='https://staging.vip2100.com/' python3 "$PREFLIGHT")"
printf '%s\n' "$out" | grep -qx 'status=ok'

echo "== export writes the origin and not stdout =="
origin_file="$(mktemp)"
out="$(pf STAGING_API_BASE='https://staging.vip2100.com/' python3 "$PREFLIGHT" --export-origin "$origin_file")"
printf '%s\n' "$out" | grep -qx 'status=ok'
if printf '%s\n' "$out" | grep -q 'vip2100'; then
  echo "export printed the origin"
  exit 1
fi
got="$(tr -d '\r\n' < "$origin_file")"
rm -f "$origin_file"
if [[ "$got" != "https://staging.vip2100.com" ]]; then
  echo "unexpected normalized origin: ${#got} bytes"
  exit 1
fi

echo "== auth status prints names only =="
out="$(pf STAGING_ADMIN_PASSWORD='sentinel-password-value' python3 "$PREFLIGHT" --auth-status)"
printf '%s\n' "$out" | grep -qx 'configured=false'
printf '%s\n' "$out" | grep -qx 'missing=STAGING_ADMIN_USERNAME'
if printf '%s\n' "$out" | grep -q 'sentinel-password-value'; then
  echo "auth status printed a password"
  exit 1
fi
out="$(pf STAGING_ADMIN_USERNAME='admin-placeholder' STAGING_ADMIN_PASSWORD='placeholder-pass' python3 "$PREFLIGHT" --auth-status)"
printf '%s\n' "$out" | grep -qx 'configured=true'
if printf '%s\n' "$out" | grep -q 'placeholder-pass'; then
  echo "auth status printed a password"
  exit 1
fi

echo "== mask emits add-mask lines only inside actions =="
out="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" GITHUB_ACTIONS=true \
  STAGING_API_BASE='https://staging.vip2100.com/' \
  STAGING_ADMIN_PASSWORD='sentinel-password-value' \
  python3 "$PREFLIGHT" --mask)"
if [[ -z "$out" ]]; then
  echo "mask produced no lines"
  exit 1
fi
while IFS= read -r line; do
  case "$line" in
    '::add-mask::'*) ;;
    *) echo "unexpected mask line"; exit 1 ;;
  esac
done <<< "$out"
printf '%s\n' "$out" | grep -qx '::add-mask::sentinel-password-value'
printf '%s\n' "$out" | grep -qx '::add-mask::https://staging.vip2100.com/api/health'
silent="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" \
  STAGING_ADMIN_PASSWORD='sentinel-password-value' \
  python3 "$PREFLIGHT" --mask)"
if [[ -n "$silent" ]]; then
  echo "mask printed outside GitHub Actions"
  exit 1
fi

stubdir="$(mktemp -d)"
trap 'rm -rf "$stubdir"' EXIT
cat > "$stubdir/curl" << 'EOF'
#!/usr/bin/env bash
out="" hdr="" url="" ua="" header_ua="" prev=""
for arg in "$@"; do
  case "$prev" in
    --output) out="$arg" ;;
    --dump-header) hdr="$arg" ;;
    --user-agent) ua="$arg" ;;
    --url) url="$arg" ;;
    --header)
      case "$arg" in
        "User-Agent:"*) header_ua="${arg#User-Agent: }" ;;
      esac
      ;;
  esac
  prev="$arg"
done
{
  printf 'ua=%s\n' "$ua"
  printf 'header_ua=%s\n' "$header_ua"
  printf 'url=%s\n' "$url"
  printf 'args=%s\n' "$*"
} > "${CURL_CAPTURE:?}"
case "${CURL_MODE:-ok}" in
  ok)
    printf 'HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\r\n' > "$hdr"
    printf '%s' '{"ok":true,"data":{"status":"ready","marker":"LEAKED-BODY-TOKEN"}}' > "$out"
    printf '200'
    ;;
  html)
    printf 'HTTP/1.1 200 OK\r\ncontent-type: text/html\r\n\r\n' > "$hdr"
    printf '%s' '<!DOCTYPE html><html>LEAKED-BODY-TOKEN</html>' > "$out"
    printf '200'
    ;;
  forbidden)
    printf 'HTTP/1.1 403 Forbidden\r\ncontent-type: text/html\r\n\r\n' > "$hdr"
    printf '%s' '<html>LEAKED-BODY-TOKEN</html>' > "$out"
    printf '403'
    ;;
  transport)
    printf 'curl: could not connect\n' >&2
    exit 28
    ;;
esac
EOF
chmod +x "$stubdir/curl"
cat > "$stubdir/flutter" << 'EOF'
#!/usr/bin/env bash
{
  printf 'pwd=%s\n' "$PWD"
  printf 'args=%s\n' "$*"
  printf 'account=%s\n' "${STAGING_SMOKE_ACCOUNT_ID-<unset>}"
} > "${FLUTTER_CAPTURE:?}"
exit 0
EOF
chmod +x "$stubdir/flutter"

probe_env() {
  local mode="$1"
  local capture="$2"
  shift 2
  env -i PATH="$stubdir:/usr/bin:/bin" HOME="${HOME:-/tmp}" \
    CURL_CAPTURE="$capture" CURL_MODE="$mode" \
    STAGING_ADMIN_PASSWORD='sentinel-password-value' \
    "$@" \
    bash "$REACH"
}

echo "== probe sends the non-Python user agent and hides the body =="
capture="$stubdir/curl-ok.txt"
out="$(probe_env ok "$capture" STAGING_API_BASE='https://staging.vip2100.com/' 2>"$stubdir/curl-ok.err")"
printf '%s\n' "$out" | grep -qx 'status=ok'
printf '%s\n' "$out" | grep -qx 'http_status=200'
if printf '%s\n%s\n' "$out" "$(cat "$stubdir/curl-ok.err")" | grep -q 'LEAKED-BODY-TOKEN'; then
  echo "probe printed the response body"
  exit 1
fi
if printf '%s\n%s\n' "$out" "$(cat "$stubdir/curl-ok.err")" | grep -q 'https://'; then
  echo "probe printed the URL"
  exit 1
fi
grep -qx 'ua=VibAbdoMobileSmoke/1.0 (+github-actions)' "$capture"
grep -qx 'header_ua=VibAbdoMobileSmoke/1.0 (+github-actions)' "$capture"
grep -qx 'url=https://staging.vip2100.com/api/health' "$capture"
if grep -q 'sentinel-password-value' "$capture"; then
  echo "curl arguments contained the password"
  exit 1
fi
if grep -q 'Python' "$capture"; then
  echo "curl used a Python user agent"
  exit 1
fi

echo "== html and 403 and transport fail without the body =="
out="$(probe_env html "$stubdir/html.txt" STAGING_API_BASE='https://staging.company.test' 2>"$stubdir/html.err" || true)"
printf '%s\n' "$out" | grep -qx 'reason=html'
if printf '%s\n' "$out" | grep -q 'LEAKED-BODY-TOKEN'; then
  echo "html failure printed the body"
  exit 1
fi
set +e
probe_env forbidden "$stubdir/forbidden.txt" STAGING_API_BASE='https://staging.company.test' >"$stubdir/forbidden.out" 2>"$stubdir/forbidden.err"
code=$?
set -e
if [[ "$code" -eq 0 ]]; then
  echo "403 must fail"
  exit 1
fi
grep -qx 'http_status=403' "$stubdir/forbidden.out"
if grep -q 'LEAKED-BODY-TOKEN' "$stubdir/forbidden.out"; then
  echo "403 printed the body"
  exit 1
fi
set +e
probe_env transport "$stubdir/transport.txt" STAGING_API_BASE='https://staging.company.test' >"$stubdir/transport.out" 2>"$stubdir/transport.err"
code=$?
set -e
if [[ "$code" -eq 0 ]]; then
  echo "transport failure must fail"
  exit 1
fi
grep -qx 'reason=transport' "$stubdir/transport.out"
grep -qx 'curl_exit=28' "$stubdir/transport.out"
if grep -q 'staging.company.test' "$stubdir/transport.out"; then
  echo "transport failure printed the host"
  exit 1
fi

echo "== /erp does not call curl =="
rm -f "$stubdir/should-not-exist.txt"
set +e
probe_env ok "$stubdir/should-not-exist.txt" STAGING_API_BASE='https://staging.secret-host.test/erp' >"$stubdir/erp.out" 2>"$stubdir/erp.err"
code=$?
set -e
if [[ "$code" -eq 0 ]]; then
  echo "/erp must fail"
  exit 1
fi
if [[ -f "$stubdir/should-not-exist.txt" ]]; then
  echo "curl ran for an /erp origin"
  exit 1
fi
grep -qx 'reason=erp-suffix' "$stubdir/erp.out"
if grep -q 'secret-host' "$stubdir/erp.out" "$stubdir/erp.err"; then
  echo "/erp probe printed the host"
  exit 1
fi

echo "== flutter smoke unsets the pin id and skips when secrets are absent =="
flutter_capture="$stubdir/flutter.txt"
rm -f "$flutter_capture"
set +e
env -i PATH="$stubdir:/usr/bin:/bin" HOME="${HOME:-/tmp}" \
  FLUTTER_CAPTURE="$flutter_capture" \
  STAGING_API_BASE='https://staging.company.test' \
  STAGING_ADMIN_USERNAME='admin-placeholder' \
  STAGING_SMOKE_ACCOUNT_ID='do-not-pass' \
  bash "$REACH" --flutter >"$stubdir/flutter-missing.out" 2>"$stubdir/flutter-missing.err"
code=$?
set -e
if [[ "$code" -eq 0 ]]; then
  echo "missing password must not start flutter"
  exit 1
fi
grep -q 'secret not configured' "$stubdir/flutter-missing.out"
if [[ -f "$flutter_capture" ]]; then
  echo "flutter ran without a password"
  exit 1
fi

env -i PATH="$stubdir:/usr/bin:/bin" HOME="${HOME:-/tmp}" \
  FLUTTER_CAPTURE="$flutter_capture" \
  STAGING_API_BASE='https://staging.company.test' \
  STAGING_ADMIN_USERNAME='admin-placeholder' \
  STAGING_ADMIN_PASSWORD='placeholder-pass' \
  STAGING_SMOKE_ACCOUNT_ID='do-not-pass' \
  bash "$REACH" --flutter >"$stubdir/flutter-ok.out"
grep -qx 'pwd='"$ROOT/packages/api_layer" "$flutter_capture"
grep -qx 'args=test test/phase7/staging_smoke_test.dart' "$flutter_capture"
grep -qx 'account=<unset>' "$flutter_capture"
if grep -q 'placeholder-pass' "$stubdir/flutter-ok.out" "$flutter_capture"; then
  echo "flutter mode printed a password"
  exit 1
fi

echo "== pin and auth notices =="
out="$(SMOKE_AUTH_MISSING='STAGING_ADMIN_PASSWORD' bash "$REACH" --skip-auth-notice)"
printf '%s\n' "$out" | grep -q 'secret not configured'
printf '%s\n' "$out" | grep -q 'STAGING_ADMIN_PASSWORD'
out="$(bash "$REACH" --pin-notice)"
printf '%s\n' "$out" | grep -q 'STAGING_SMOKE_ACCOUNT_ID'
printf '%s\n' "$out" | grep -q 'P-07'

echo "reachability_test ok"
