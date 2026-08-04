#!/usr/bin/env bash
# Build a universal Sparkle update zip from exported Developer ID apps and
# refresh docs/appcast.xml.
#
# generate_appcast rejects multiple archives that share the same CFBundleVersion,
# so arm64 + amd64 thin zips cannot both sit in the feed directory. We lipo a
# single universal Online.app instead.
#
# Usage (after arm64 + amd64 signed exports exist):
#   RELEASE_VERSION=0.2.28 SPARKLE_PRIVATE_KEY=... ./scripts/prepare-sparkle-feed.sh
#
# Env:
#   RELEASE_VERSION       — version segment in artifact names (required)
#   RELEASE_TAG           — git tag used for GitHub download URLs (default: v$RELEASE_VERSION)
#   SPARKLE_PRIVATE_KEY   — Ed25519 private key (required in CI)
#   SPARKLE_CHANNEL       — optional; set to "prerelease" for -build / prerelease tags
#   SPARKLE_TOOLS_VERSION — Sparkle release used for generate_appcast (default: 2.9.5)
#   CODE_SIGN_IDENTITY    — signing identity for re-signing after lipo (default: Developer ID Application)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${RELEASE_VERSION:?RELEASE_VERSION is required}"
TAG="${RELEASE_TAG:-v${VERSION}}"
CHANNEL="${SPARKLE_CHANNEL:-}"
IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"
FEED_DIR="$ROOT/build/sparkle-feed"
TOOLS_DIR="$ROOT/build/sparkle-tools"
UNIVERSAL_ROOT="$ROOT/build/universal"
UNIVERSAL_APP="$UNIVERSAL_ROOT/export/Online.app"
APPCAST_OUT="$ROOT/docs/appcast.xml"
DOWNLOAD_PREFIX="https://github.com/Jubblin/online/releases/download/${TAG}/"
ZIP_PATH="$FEED_DIR/Online-${VERSION}.zip"

mkdir -p "$FEED_DIR" "$TOOLS_DIR"
rm -f "$FEED_DIR"/*.zip "$FEED_DIR"/*.xml "$FEED_DIR"/*.md

download_sparkle_tools() {
  local version="${SPARKLE_TOOLS_VERSION:-2.9.5}"
  local archive="$TOOLS_DIR/Sparkle-${version}.tar.xz"
  if [[ ! -x "$TOOLS_DIR/bin/generate_appcast" ]]; then
    curl -fsSL --proto '=https' --proto-redir '=https' -o "$archive" \
      "https://github.com/sparkle-project/Sparkle/releases/download/${version}/Sparkle-${version}.tar.xz"
    tar -xJf "$archive" -C "$TOOLS_DIR"
  fi
  GENERATE_APPCAST="$(find "$TOOLS_DIR" -name generate_appcast -type f | head -1)"
  if [[ -z "$GENERATE_APPCAST" || ! -x "$GENERATE_APPCAST" ]]; then
    echo "error: generate_appcast not found after extracting Sparkle tools" >&2
    exit 1
  fi
}

# Merge thin Mach-O binaries from arm64 + amd64 exports into one universal app.
create_universal_app() {
  local arm_app="$ROOT/build/arm64/export/Online.app"
  local intel_app="$ROOT/build/amd64/export/Online.app"

  if [[ ! -d "$arm_app" ]]; then
    echo "error: missing exported app at $arm_app" >&2
    exit 1
  fi
  if [[ ! -d "$intel_app" ]]; then
    echo "error: missing exported app at $intel_app" >&2
    exit 1
  fi

  rm -rf "$UNIVERSAL_ROOT"
  mkdir -p "$UNIVERSAL_ROOT/export"
  /usr/bin/ditto "$arm_app" "$UNIVERSAL_APP"

  local rel arm_file intel_file
  while IFS= read -r -d '' rel; do
    arm_file="$arm_app/$rel"
    intel_file="$intel_app/$rel"
    [[ -f "$intel_file" ]] || continue
    if /usr/bin/file -b "$arm_file" | grep -q 'Mach-O'; then
      /usr/bin/lipo -create "$arm_file" "$intel_file" -output "$UNIVERSAL_APP/$rel.universal"
      mv "$UNIVERSAL_APP/$rel.universal" "$UNIVERSAL_APP/$rel"
    fi
  done < <(cd "$arm_app" && find . -type f -print0)

  echo "Created universal app at $UNIVERSAL_APP"
  /usr/bin/lipo -info "$UNIVERSAL_APP/Contents/MacOS/Online" || true
}

# Re-sign after lipo. Prefer nested Sparkle helpers before the outer bundle.
resign_universal_app() {
  local sparkle="$UNIVERSAL_APP/Contents/Frameworks/Sparkle.framework/Versions/B"
  local sign=(/usr/bin/codesign --force --options runtime --timestamp --sign "$IDENTITY")
  local entitlements
  entitlements="$(mktemp -t online-sparkle-ents.XXXXXX.plist)"
  # Use expanded entitlements from the already-exported arm64 app (not the raw
  # source plist, which still contains $(PRODUCT_BUNDLE_IDENTIFIER)).
  /usr/bin/codesign -d --entitlements ":-" "$ROOT/build/arm64/export/Online.app" >"$entitlements" 2>/dev/null \
    || /usr/bin/codesign -d --entitlements "$entitlements" "$ROOT/build/arm64/export/Online.app"

  if [[ -d "$sparkle/XPCServices/Installer.xpc" ]]; then
    "${sign[@]}" "$sparkle/XPCServices/Installer.xpc"
  fi
  if [[ -d "$sparkle/XPCServices/Downloader.xpc" ]]; then
    "${sign[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
  fi
  if [[ -f "$sparkle/Autoupdate" ]]; then
    "${sign[@]}" "$sparkle/Autoupdate"
  fi
  if [[ -d "$sparkle/Updater.app" ]]; then
    "${sign[@]}" "$sparkle/Updater.app"
  fi
  if [[ -d "$UNIVERSAL_APP/Contents/Frameworks/Sparkle.framework" ]]; then
    "${sign[@]}" "$UNIVERSAL_APP/Contents/Frameworks/Sparkle.framework"
  fi

  "${sign[@]}" --entitlements "$entitlements" "$UNIVERSAL_APP"
  rm -f "$entitlements"
  /usr/bin/codesign --verify --verbose=2 "$UNIVERSAL_APP"
}

zip_universal_app() {
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$UNIVERSAL_APP" "$ZIP_PATH"
  echo "Wrote $ZIP_PATH"
}

download_sparkle_tools
create_universal_app
resign_universal_app
zip_universal_app

# Seed from the committed appcast so history accumulates across releases.
if [[ -f "$APPCAST_OUT" ]]; then
  cp "$APPCAST_OUT" "$FEED_DIR/appcast.xml"
fi

# Release notes sidecar — basename must match the zip stem for generate_appcast.
NOTES="$FEED_DIR/Online-${VERSION}.md"
{
  echo "# Online ${VERSION}"
  echo
  if [[ -f "$ROOT/release-notes.md" ]]; then
    sed -n '1,/^---$/p' "$ROOT/release-notes.md" | sed '$d' || cat "$ROOT/release-notes.md"
  else
    echo "Update to Online ${VERSION}."
  fi
} >"$NOTES"

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "error: SPARKLE_PRIVATE_KEY is required to sign the appcast" >&2
  exit 1
fi

GENERATE_ARGS=(
  --ed-key-file -
  --embed-release-notes
  --download-url-prefix "$DOWNLOAD_PREFIX"
  --link "https://github.com/Jubblin/online/releases"
  -o "$FEED_DIR/appcast.xml"
)

if [[ -n "$CHANNEL" ]]; then
  GENERATE_ARGS+=(--channel "$CHANNEL")
fi

printf '%s\n' "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" \
  "${GENERATE_ARGS[@]}" \
  "$FEED_DIR"

if [[ ! -f "$FEED_DIR/appcast.xml" ]]; then
  echo "error: appcast.xml was not generated" >&2
  exit 1
fi

cp "$FEED_DIR/appcast.xml" "$APPCAST_OUT"
echo "Updated $APPCAST_OUT (download prefix: $DOWNLOAD_PREFIX${CHANNEL:+, channel: $CHANNEL})"
ls -la "$FEED_DIR"
