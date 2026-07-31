#!/usr/bin/env bash
# Build a Developer ID signed and notarized Online DMG for one architecture.
# Usage: ./scripts/build-signed-dmg.sh [Configuration] [arm64|amd64]
# Env:
#   DEVELOPMENT_TEAM              — required Apple Team ID
#   RELEASE_VERSION               — version segment in the DMG name (default: MARKETING_VERSION)
#   ARCH                          — architecture when argv[2] is omitted (arm64|amd64)
#   DEVELOPER_ID_CERTIFICATE_P12  — optional base64 .p12 (or APPLE_CERTIFICATE_P12)
#   P12_PASSWORD                  — .p12 password when importing in CI
#   APP_STORE_CONNECT_API_KEY_*   — optional notarization credentials
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Online"
CONFIGURATION="${1:-Release}"
ARCH_INPUT="${2:-${ARCH:-}}"

: "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is required}"

# shellcheck source=/dev/null
source "$ROOT/scripts/resolve-release-arch.sh"
resolve_release_arch "$ARCH_INPUT"

VERSION="${RELEASE_VERSION:-"$("$ROOT/scripts/read-marketing-version.sh")"}"
BUILD_DIR="$ROOT/build/${ARCH_LABEL}"
ARCHIVE_PATH="$BUILD_DIR/Online.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions-developer-id.plist"
APP_PATH="$EXPORT_DIR/Online.app"
DMG_PATH="$ROOT/build/Online-${VERSION}-${ARCH_LABEL}.dmg"

cd "$ROOT"
mkdir -p "$BUILD_DIR"

CERTIFICATE_P12="${DEVELOPER_ID_CERTIFICATE_P12:-${APPLE_CERTIFICATE_P12:-}}"
export CERTIFICATE_P12
export P12_PASSWORD="${P12_PASSWORD:-}"

if [[ -n "$CERTIFICATE_P12" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/scripts/ci-setup-keychain.sh"
fi

cat >"$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>${DEVELOPMENT_TEAM}</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild archive \
  -project Online.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS="$XCODE_ARCH" \
  ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates

rm -f "$DMG_PATH"
"$ROOT/scripts/package-dmg.sh" "$APP_PATH" "$DMG_PATH"

if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY:-}" ]]; then
  KEY_PATH="$BUILD_DIR/AuthKey.p8"
  printf '%s' "$APP_STORE_CONNECT_API_KEY" >"$KEY_PATH"

  xcrun notarytool submit "$DMG_PATH" \
    --key "$KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait

  xcrun stapler staple "$DMG_PATH"
  echo "Notarized and stapled: $DMG_PATH"
else
  echo "warning: App Store Connect API key not set; skipping notarization"
fi

echo "Built signed DMG: $DMG_PATH ($XCODE_ARCH)"
