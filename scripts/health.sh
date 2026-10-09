#!/usr/bin/env bash
# Run the local Health Stack (mirrors CLAUDE.md and CI quality + test jobs).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

require_cmd() {
  local name="$1"
  local brew_pkg="$2"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "error: $name not installed (brew install $brew_pkg)" >&2
    exit 1
  fi
}

echo "== SwiftLint =="
require_cmd swiftlint swiftlint
swiftlint lint --strict --quiet

echo "== ShellCheck =="
require_cmd shellcheck shellcheck
shellcheck scripts/*.sh

echo "== Docs site sync =="
./scripts/sync-docs-site.sh --check

echo "== Typecheck (xcodebuild build) =="
xcodebuild \
  -project Foghorn.xcodeproj \
  -scheme Foghorn \
  -configuration Debug \
  -derivedDataPath build-health \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=NO \
  build

# UI tests need a signed runner; unsigned local builds kill it before it
# connects, so they run in CI only (#167).
echo "== Test (xcodebuild test, unit tests) =="
xcodebuild \
  -project Foghorn.xcodeproj \
  -scheme Foghorn \
  -configuration Debug \
  -derivedDataPath build-health \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=NO \
  -skip-testing:FoghornUITests \
  test

echo "Health stack passed."
