#!/usr/bin/env bash
# Archive, export, and upload FoghorniOS to TestFlight (App Store).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="FoghorniOS"
CONFIGURATION="${1:-Release}"
BUILD_DIR="$ROOT/build-ios"
ARCHIVE_PATH="$BUILD_DIR/FoghorniOS.xcarchive"
EXPORT_DIR="$BUILD_DIR/store-export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions-appstore-ios.plist"

if [[ -z "${APP_STORE_CONNECT_API_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" || -z "${APP_STORE_CONNECT_API_KEY:-}" ]]; then
  echo "App Store Connect API credentials not configured; skipping iOS TestFlight upload"
  exit 0
fi

: "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is required}"

cd "$ROOT"

CERTIFICATE_P12="${APP_STORE_CERTIFICATE_P12:-${APPLE_CERTIFICATE_P12:-}}"
export CERTIFICATE_P12
export P12_PASSWORD="${P12_PASSWORD:-}"

if [[ -n "$CERTIFICATE_P12" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/scripts/ci-setup-keychain.sh"
fi

mkdir -p "$BUILD_DIR"

cat >"$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>${DEVELOPMENT_TEAM}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

xcodebuild archive \
  -project Foghorn.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates

IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -n 1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "error: no .ipa found in $EXPORT_DIR" >&2
  exit 1
fi

KEY_PATH="$BUILD_DIR/AuthKey.p8"
printf '%s' "$APP_STORE_CONNECT_API_KEY" >"$KEY_PATH"

xcrun altool --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --apiKeyPath "$KEY_PATH"

echo "Uploaded to App Store Connect: $IPA_PATH"
