#!/usr/bin/env bash
# Install one side-by-side Android NDK, deleting a partial tree between tries.
#
# Flutter's flutter.ndkVersion (28.2.13676358 on Flutter 3.47.7) is not
# preinstalled on GitHub-hosted ubuntu-latest. Gradle then asks sdkmanager to
# download it during configuration. That download sometimes stores a truncated
# zip, and sdkmanager exits 1 with "Error on ZipFile unknown archive".
# A later attempt unpacks the same corrupt zip unless the partial NDK directory
# and sdkmanager's download cache are removed first.
set -euo pipefail

NDK_VERSION="${1:-}"
ATTEMPTS=4

if [[ ! "${NDK_VERSION}" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  echo "Usage: install.sh <ndk-version>  (for example 28.2.13676358)" >&2
  exit 2
fi
if [[ -z "${ANDROID_HOME:-}" || ! -d "${ANDROID_HOME}" ]]; then
  echo "ANDROID_HOME must point at an Android SDK directory." >&2
  exit 1
fi

SDKMANAGER="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
NDK_DIR="${ANDROID_HOME}/ndk/${NDK_VERSION}"
VERSION_RE="${NDK_VERSION//./\\.}"

if [[ ! -x "${SDKMANAGER}" ]]; then
  echo "sdkmanager not found at ${SDKMANAGER}" >&2
  exit 1
fi

echo "NDK directories under ${ANDROID_HOME}/ndk:"
if [[ -d "${ANDROID_HOME}/ndk" ]]; then
  ls -1 "${ANDROID_HOME}/ndk"
else
  echo "(none yet)"
fi

ndk_ready() {
  local clang
  [[ -x "${NDK_DIR}/ndk-build" ]] || return 1
  [[ -f "${NDK_DIR}/source.properties" ]] || return 1
  grep -Eq "^Pkg\\.Revision[[:space:]]*=[[:space:]]*${VERSION_RE}[[:space:]]*$" "${NDK_DIR}/source.properties" || return 1
  # Command substitution, not a pipe into grep -q: grep -q would SIGPIPE find,
  # and pipefail would treat a complete NDK as missing.
  clang="$(find "${NDK_DIR}/toolchains/llvm/prebuilt" -type f -name clang -print -quit 2>/dev/null || true)"
  [[ -n "${clang}" && -x "${clang}" ]]
}

clear_partial() {
  rm -rf "${NDK_DIR}" \
    "${ANDROID_HOME}/.temp" \
    "${ANDROID_HOME}/.downloadIntermediates"
  if [[ -n "${HOME:-}" && "${HOME}" != "/" ]]; then
    rm -rf "${HOME}/.android/cache"
  fi
}

if ndk_ready; then
  echo "NDK ${NDK_VERSION} is already installed at ${NDK_DIR}"
  exit 0
fi

mkdir -p "${ANDROID_HOME}/licenses"
if [[ ! -s "${ANDROID_HOME}/licenses/android-sdk-license" ]]; then
  printf '%s\n' "24333f8a63b6825ea9c5514f83c2829b004d1fee" \
    > "${ANDROID_HOME}/licenses/android-sdk-license"
fi

for attempt in $(seq 1 "${ATTEMPTS}"); do
  echo "Installing ndk;${NDK_VERSION} (attempt ${attempt}/${ATTEMPTS})"
  clear_partial
  set +e
  set +o pipefail
  yes | "${SDKMANAGER}" --sdk_root="${ANDROID_HOME}" --install "ndk;${NDK_VERSION}"
  status=$?
  set -o pipefail
  set -e
  if ndk_ready; then
    echo "NDK ${NDK_VERSION} installed at ${NDK_DIR}"
    echo "NDK directories under ${ANDROID_HOME}/ndk:"
    ls -1 "${ANDROID_HOME}/ndk"
    exit 0
  fi
  echo "sdkmanager exited ${status} and ${NDK_DIR} is not a complete NDK ${NDK_VERSION}. Removing the partial directory."
  clear_partial
  if [[ "${attempt}" -lt "${ATTEMPTS}" ]]; then
    sleep $((attempt * 5))
  fi
done

echo "Failed to install NDK ${NDK_VERSION} after ${ATTEMPTS} attempts." >&2
exit 1
