#!/usr/bin/env bash
# Build an unsigned Online DMG for one architecture.
# Usage: ./scripts/build-dmg.sh [Configuration] [arm64|amd64]
# Env:
#   RELEASE_VERSION — version segment in the DMG name (default: MARKETING_VERSION)
#   ARCH            — architecture when argv[2] is omitted (arm64|amd64)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Online"
CONFIGURATION="${1:-Release}"
ARCH_INPUT="${2:-${ARCH:-}}"

# shellcheck source=/dev/null
source "$ROOT/scripts/resolve-release-arch.sh"
resolve_release_arch "$ARCH_INPUT"

VERSION="${RELEASE_VERSION:-"$("$ROOT/scripts/read-marketing-version.sh")"}"
BUILD_DIR="$ROOT/build/${ARCH_LABEL}"
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/Online.app"
DMG_PATH="$ROOT/build/Online-${VERSION}-${ARCH_LABEL}.dmg"
STAGING="$BUILD_DIR/dmg-staging"

cd "$ROOT"
mkdir -p "$ROOT/build"

XCODEBUILD_ARGS=(
  -project Online.xcodeproj
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$BUILD_DIR"
  ARCHS="$XCODE_ARCH"
  ONLY_ACTIVE_ARCH=NO
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
)

if [[ -n "${CODE_SIGNING_ALLOWED+x}" ]]; then
  XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED")
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" build

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

hdiutil create \
  -volname "Online" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built app: $APP_PATH ($XCODE_ARCH)"
echo "Built DMG: $DMG_PATH"
