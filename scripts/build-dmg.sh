#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Online"
CONFIGURATION="${1:-Release}"
BUILD_DIR="$ROOT/build"
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/Online.app"
DMG_PATH="$BUILD_DIR/Online.dmg"
STAGING="$BUILD_DIR/dmg-staging"

cd "$ROOT"

xcodebuild \
  -project Online.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  build

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

hdiutil create \
  -volname "Online" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built app: $APP_PATH"
echo "Built DMG: $DMG_PATH"
