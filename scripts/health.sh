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

# Same gate as CI: any unused code fails; annotate false positives in source (#169, #170).
# --clean-build: Periphery's cached index goes stale across incremental builds and
# reports phantom findings locally; CI always builds clean.
# Optional locally so contributors without Periphery aren't blocked.
echo "== Dead code (Periphery) =="
if command -v periphery >/dev/null 2>&1; then
  periphery scan \
    --config .periphery.yml \
    --disable-update-check \
    --quiet \
    --strict \
    --clean-build
else
  echo "warning: periphery not installed (brew install periphery); skipping dead-code check" >&2
fi

echo "Health stack passed."
