#!/usr/bin/env bash
# Checks used by .github/workflows/android-release.yml.
#   android_release_preflight.sh secrets
#   android_release_preflight.sh version
# Writes KEY=VALUE lines to stdout and, when set, to $GITHUB_OUTPUT.
# Secret values are never printed.
set -euo pipefail

usage() {
  echo "usage: android_release_preflight.sh secrets|version" >&2
  exit 2
}

emit() {
  local key="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
  fi
  printf '%s=%s\n' "$key" "$value"
}

is_blank() {
  [[ "${1-}" =~ ^[[:space:]]*$ ]]
}

trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

cmd_secrets() {
  local missing=()
  is_blank "${ANDROID_KEYSTORE_BASE64-}" && missing+=(ANDROID_KEYSTORE_BASE64)
  is_blank "${ANDROID_KEYSTORE_PASSWORD-}" && missing+=(ANDROID_KEYSTORE_PASSWORD)
  is_blank "${ANDROID_KEY_ALIAS-}" && missing+=(ANDROID_KEY_ALIAS)
  is_blank "${ANDROID_KEY_PASSWORD-}" && missing+=(ANDROID_KEY_PASSWORD)

  if [[ "${#missing[@]}" -eq 4 ]]; then
    emit mode skip
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'
## Signed release skipped

None of the Android signing secrets are set, so no AAB or APK was built.

Add these repository secrets, then re-run this workflow:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

See `docs/RELEASE.md`.
EOF
    fi
    echo "::notice title=Signed release skipped::Android signing secrets are not set. No AAB or APK was built."
    exit 0
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "::error title=Incomplete Android signing secrets::Missing: ${missing[*]}. No release artifact was built. See docs/RELEASE.md." >&2
    exit 1
  fi

  emit mode build
}

cmd_version() {
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local pubspec="${PUBSPEC:-$repo_root/pubspec.yaml}"
  if [[ ! -f "$pubspec" ]]; then
    echo "pubspec not found: $pubspec" >&2
    exit 1
  fi

  local pubspec_version
  pubspec_version="$(awk '/^version:[[:space:]]*/ { print $2; exit }' "$pubspec" | tr -d '\r')"
  if [[ ! "$pubspec_version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$ ]]; then
    echo "pubspec.yaml version must be MAJOR.MINOR.PATCH+versionCode with versionCode >= 1 (found '${pubspec_version:-<missing>}')." >&2
    exit 1
  fi
  local pubspec_name="${BASH_REMATCH[1]}"
  local pubspec_code="${BASH_REMATCH[2]}"
  if [[ ${#pubspec_code} -gt 10 || "$pubspec_code" -gt 2100000000 ]]; then
    echo "versionCode must be <= 2100000000 (Play limit). Found $pubspec_code." >&2
    exit 1
  fi

  local event
  event="$(trim "${EVENT_NAME:-}")"
  local version_name="$pubspec_name"
  local version_code="$pubspec_code"
  local regressed=false

  if [[ "$event" == "push" ]]; then
    local tag
    tag="$(trim "${GIT_TAG:-}")"
    local input_name input_code
    input_name="$(trim "${INPUT_BUILD_NAME:-}")"
    input_code="$(trim "${INPUT_BUILD_NUMBER:-}")"
    if [[ -n "$input_name" || -n "$input_code" ]]; then
      echo "version overrides are ignored for tag pushes; pubspec.yaml and the tag are the source of truth." >&2
    fi
    if [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "$pubspec_name" ]]; then
        echo "Tag $tag does not match pubspec versionName $pubspec_name." >&2
        exit 1
      fi
    elif [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "$pubspec_name" || "${BASH_REMATCH[2]}" != "$pubspec_code" ]]; then
        echo "Tag $tag does not match pubspec ${pubspec_name}+${pubspec_code}." >&2
        exit 1
      fi
    else
      echo "Tag '${tag:-<missing>}' must be vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH+versionCode." >&2
      exit 1
    fi
  else
    local input_name input_code
    input_name="$(trim "${INPUT_BUILD_NAME:-}")"
    input_code="$(trim "${INPUT_BUILD_NUMBER:-}")"
    if [[ -n "$input_name" ]]; then
      if [[ ! "$input_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "build_name must be MAJOR.MINOR.PATCH (found '$input_name')." >&2
        exit 1
      fi
      version_name="$input_name"
    fi
    if [[ -n "$input_code" ]]; then
      if [[ ! "$input_code" =~ ^[1-9][0-9]*$ ]]; then
        echo "build_number must be an integer >= 1 with no leading zero (found '$input_code')." >&2
        exit 1
      fi
      if [[ ${#input_code} -gt 10 || "$input_code" -gt 2100000000 ]]; then
        echo "build_number must be <= 2100000000 (Play limit). Found $input_code." >&2
        exit 1
      fi
      if [[ "$input_code" -lt "$pubspec_code" ]]; then
        regressed=true
        echo "warning: build_number $input_code is lower than pubspec versionCode $pubspec_code. Play rejects a versionCode that does not increase." >&2
      fi
      version_code="$input_code"
    fi
  fi

  emit version_name "$version_name"
  emit version_code "$version_code"
  emit version_regressed "$regressed"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Version"
      echo "- versionName: \`$version_name\`"
      echo "- versionCode: \`$version_code\`"
      if [[ "$regressed" == true ]]; then
        echo "- Play requires a higher versionCode than anything already uploaded. This override is lower than pubspec."
      fi
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

case "${1:-}" in
  secrets) cmd_secrets ;;
  version) cmd_version ;;
  *) usage ;;
esac
