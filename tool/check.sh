#!/usr/bin/env bash
# Analyze and test the app and the API package. No network calls.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter analyze
flutter test

(
  cd packages/api_layer
  flutter analyze
  flutter test
)
