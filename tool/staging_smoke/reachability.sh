#!/usr/bin/env bash
# P-01 staging smoke entrypoint.
#
# HTTP is curl only. The User-Agent is VibAbdoMobileSmoke/1.0 (+github-actions),
# never Python-urllib. tool/staging_smoke/preflight.py does not open a socket.
#
# STAGING_API_BASE is the origin https://staging.vip2100.com with no /erp suffix.
# An empty value or an /erp suffix fails. The value is not printed.
# STAGING_SMOKE_ACCOUNT_ID is never sent. setPinned was removed from the
# smoke test and stays deferred to P-07 pending Ali's decision.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFLIGHT="$ROOT/tool/staging_smoke/preflight.py"
UA='VibAbdoMobileSmoke/1.0 (+github-actions)'

usage() {
  echo "usage: reachability.sh [--mask|--check-only|--auth-status|--skip-auth-notice|--pin-notice|--flutter]" >&2
  exit 2
}

mask_if_actions() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    python3 "$PREFLIGHT" --mask
  fi
}

check_only() {
  python3 "$PREFLIGHT"
}

auth_status() {
  local out
  out="$(python3 "$PREFLIGHT" --auth-status)"
  printf '%s\n' "$out"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s\n' "$out" >> "$GITHUB_OUTPUT"
  fi
}

skip_auth_notice() {
  local missing="${SMOKE_AUTH_MISSING:-STAGING_ADMIN_USERNAME,STAGING_ADMIN_PASSWORD}"
  echo "::notice title=secret not configured::Authenticated P7-01 (login, GET /api/me, section list) was skipped. Secret not configured: ${missing}."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### Authenticated smoke"
      echo
      echo "Skipped. Secret not configured: \`${missing}\`."
      echo
      echo "Unauthenticated \`GET /api/health\` already ran. No login was attempted."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

pin_notice() {
  echo "::notice title=STAGING_SMOKE_ACCOUNT_ID skipped::STAGING_SMOKE_ACCOUNT_ID is not read. setPinned was removed from the smoke. The pin write stays deferred to P-07 pending Ali's decision."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### Pin write"
      echo
      echo "Skipped. \`STAGING_SMOKE_ACCOUNT_ID\` is not read and is not set."
      echo "setPinned is not in this smoke. It stays deferred to P-07 pending Ali's decision. Logout remains the only write inside the local authenticated smoke, and GitHub does not run that smoke."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

refuse_erp_url() {
  local url="$1"
  case "$url" in
    */erp|*/erp/|*/erp/*)
      echo "::error title=Staging origin refused::Refusing to request a URL whose path contains /erp. The configured value was not printed."
      echo "status=fail"
      echo "reason=erp-suffix"
      return 1
      ;;
  esac
}

probe() {
  local tmp origin_file origin health code curl_exit preflight_out
  mask_if_actions
  tmp="$(mktemp -d)"
  # Expand now. A local is gone when EXIT runs, and set -u would then fail.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  origin_file="$tmp/origin"
  # Keep the success line out of the log. Failures still print status and ::error.
  if ! preflight_out="$(python3 "$PREFLIGHT" --export-origin "$origin_file" 2>"$tmp/preflight.err")"; then
    printf '%s\n' "$preflight_out"
    cat "$tmp/preflight.err" >&2
    exit 1
  fi
  origin="$(tr -d '\r\n' < "$origin_file")"
  rm -f "$origin_file"
  if [[ -z "$origin" ]]; then
    echo "::error title=Staging origin refused::Normalized origin was empty. The value was not printed."
    echo "status=fail"
    echo "reason=empty"
    exit 1
  fi
  health="${origin}/api/health"
  refuse_erp_url "$health"
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::add-mask::%s\n' "$origin"
    printf '::add-mask::%s\n' "$health"
  fi

  set +e
  code="$(
    curl \
      --silent \
      --proto '=https' \
      --max-redirs 0 \
      --max-time 30 \
      --retry 0 \
      --user-agent "$UA" \
      --header "Accept: application/json" \
      --header "User-Agent: ${UA}" \
      --output "$tmp/body" \
      --dump-header "$tmp/headers" \
      --write-out '%{http_code}' \
      --url "$health" \
      2>"$tmp/err"
  )"
  curl_exit=$?
  set -e
  code="${code//$'\n'/}"
  code="${code//$'\r'/}"

  if [[ "$curl_exit" -ne 0 || ! "$code" =~ ^[0-9]{3}$ ]]; then
    echo "status=fail"
    echo "reason=transport"
    echo "curl_exit=${curl_exit}"
    echo "::error title=Staging reachability failed::curl exit ${curl_exit}. The URL was not printed."
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "### Unauthenticated reachability"
        echo
        echo "Failed before an HTTP status (curl exit ${curl_exit})."
        echo
        echo "User-Agent: \`${UA}\`. The URL was not printed."
      } >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 1
  fi

  if [[ "$code" == "200" ]] && [[ -f "$tmp/body" ]] && grep -qiE '<html|<!doctype' "$tmp/body"; then
    echo "status=fail"
    echo "reason=html"
    echo "http_status=200"
    echo "::error title=Staging reachability failed::GET /api/health returned HTML. STAGING_API_BASE must be the origin without an /erp suffix. The URL was not printed."
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "### Unauthenticated reachability"
        echo
        echo "http_status=200 but the body was HTML. An \`/erp\` suffix returns HTML instead of the API."
        echo
        echo "The URL was not printed."
      } >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 1
  fi

  if [[ "$code" != "200" ]]; then
    echo "status=fail"
    echo "reason=http"
    echo "http_status=${code}"
    if [[ "$code" == "403" ]]; then
      echo "::error title=Staging reachability failed::HTTP 403 from GET /api/health. User-Agent was ${UA}, not a Python user agent. The URL was not printed."
    else
      echo "::error title=Staging reachability failed::HTTP ${code} from GET /api/health. The URL was not printed."
    fi
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "### Unauthenticated reachability"
        echo
        echo "http_status=${code}"
        echo
        echo "User-Agent: \`${UA}\`. The URL was not printed."
      } >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 1
  fi

  echo "status=ok"
  echo "http_status=200"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### Unauthenticated reachability"
      echo
      echo "GET \`/api/health\` returned http_status=200."
      echo
      echo "User-Agent: \`${UA}\`. The URL was not printed."
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

flutter_smoke() {
  local origin_file auth_out
  # Any non-empty CI or GITHUB_ACTIONS value means this process is on GitHub.
  # GitHub may probe health and cold start only. It must not log in or write.
  # ${VAR-} keeps `set -u` quiet when the variable is unset.
  local ci_guard="${CI-}"
  local actions_guard="${GITHUB_ACTIONS-}"
  ci_guard="${ci_guard//[[:space:]]/}"
  actions_guard="${actions_guard//[[:space:]]/}"
  if [[ -n "$ci_guard" || -n "$actions_guard" ]]; then
    echo "::error title=Staging write refused::Refusing the authenticated smoke on GitHub. CI or GITHUB_ACTIONS is set. GitHub may only call unauthenticated GET /api/health and the cold-start measurement."
    exit 2
  fi
  mask_if_actions
  unset STAGING_SMOKE_ACCOUNT_ID
  if [[ -n "${STAGING_SMOKE_ACCOUNT_ID:-}" ]]; then
    echo "::error title=Pin write refused::STAGING_SMOKE_ACCOUNT_ID is set. This workflow does not run the pin write (P-07)."
    exit 1
  fi
  auth_out="$(python3 "$PREFLIGHT" --auth-status)"
  if ! printf '%s\n' "$auth_out" | grep -qx 'configured=true'; then
    echo "::error title=secret not configured::Refusing to start the authenticated smoke without STAGING_ADMIN_USERNAME and STAGING_ADMIN_PASSWORD."
    printf '%s\n' "$auth_out"
    exit 1
  fi
  origin_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$origin_file'" EXIT
  if ! python3 "$PREFLIGHT" --quiet --export-origin "$origin_file"; then
    exit 1
  fi
  rm -f "$origin_file"
  echo "::notice title=STAGING_SMOKE_ACCOUNT_ID skipped::Pin write skipped. STAGING_SMOKE_ACCOUNT_ID is unset. setPinned stays deferred to P-07 pending Ali's decision."
  (
    cd "$ROOT/packages/api_layer"
    flutter test test/phase7/staging_smoke_test.dart
  )
}

cmd="${1:-probe}"
case "$cmd" in
  --mask)
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      python3 "$PREFLIGHT" --mask
    fi
    ;;
  --check-only) check_only ;;
  --auth-status) auth_status ;;
  --skip-auth-notice) skip_auth_notice ;;
  --pin-notice) pin_notice ;;
  --flutter) flutter_smoke ;;
  probe) probe ;;
  *) usage ;;
esac
