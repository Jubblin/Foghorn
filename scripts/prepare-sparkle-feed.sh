#!/usr/bin/env bash
# Build Sparkle update zips from exported Developer ID apps and refresh docs/appcast.xml.
#
# Usage (after arm64 + amd64 signed exports exist):
#   RELEASE_VERSION=0.2.27 SPARKLE_PRIVATE_KEY=... ./scripts/prepare-sparkle-feed.sh
#
# Env:
#   RELEASE_VERSION       — version segment in artifact names (required)
#   RELEASE_TAG           — git tag used for GitHub download URLs (default: v$RELEASE_VERSION)
#   SPARKLE_PRIVATE_KEY   — Ed25519 private key (required in CI)
#   SPARKLE_CHANNEL       — optional; set to "prerelease" for -build / prerelease tags
#   SPARKLE_TOOLS_VERSION — Sparkle release used for generate_appcast (default: 2.9.5)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${RELEASE_VERSION:?RELEASE_VERSION is required}"
TAG="${RELEASE_TAG:-v${VERSION}}"
CHANNEL="${SPARKLE_CHANNEL:-}"
FEED_DIR="$ROOT/build/sparkle-feed"
TOOLS_DIR="$ROOT/build/sparkle-tools"
APPCAST_OUT="$ROOT/docs/appcast.xml"
DOWNLOAD_PREFIX="https://github.com/Jubblin/online/releases/download/${TAG}/"

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

zip_app() {
  local arch_label="$1"
  local app_path="$ROOT/build/${arch_label}/export/Online.app"
  local zip_path="$FEED_DIR/Online-${VERSION}-${arch_label}.zip"

  if [[ ! -d "$app_path" ]]; then
    echo "error: missing exported app at $app_path" >&2
    exit 1
  fi

  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
  echo "Wrote $zip_path"
}

download_sparkle_tools
zip_app arm64
zip_app amd64

# Seed from the committed appcast so history accumulates across releases.
if [[ -f "$APPCAST_OUT" ]]; then
  cp "$APPCAST_OUT" "$FEED_DIR/appcast.xml"
fi

# Optional release notes sidecar (same basename as first archive family).
NOTES="$FEED_DIR/Online-${VERSION}.md"
{
  echo "# Online ${VERSION}"
  echo
  if [[ -f "$ROOT/release-notes.md" ]]; then
    # Strip install footer noise when present; keep changelog body.
    sed -n '1,/^---$/p' "$ROOT/release-notes.md" | sed '$d' || cat "$ROOT/release-notes.md"
  else
    echo "Update to Online ${VERSION}."
  fi
} >"$NOTES"

# Copy notes next to each zip basename so generate_appcast can attach them.
cp "$NOTES" "$FEED_DIR/Online-${VERSION}-arm64.md"
cp "$NOTES" "$FEED_DIR/Online-${VERSION}-amd64.md"

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

# generate_appcast reads the key from stdin when --ed-key-file -
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
