#!/usr/bin/env bash
# Stage Foghorn.app into a install-friendly DMG with Applications symlink and volume icon.
# Usage: ./scripts/package-dmg.sh <Foghorn.app path> <output.dmg path>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:?Usage: package-dmg.sh <Foghorn.app> <output.dmg>}"
DMG_PATH="${2:?Usage: package-dmg.sh <Foghorn.app> <output.dmg>}"
VOLUME_NAME="Foghorn"
VOLUME_ICON="$ROOT/packaging/VolumeIcon.icns"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/foghorn-dmg.XXXXXX")"
STAGING="$WORK/staging"
RW_DMG="$WORK/rw.dmg"
MOUNT_ROOT="$WORK/mnt"

cleanup() {
  if [[ -n "${ATTACHED_DEV:-}" ]]; then
    hdiutil detach "$ATTACHED_DEV" -quiet -force 2>/dev/null || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

[[ -d "$APP_PATH" ]] || {
  echo "error: app not found: $APP_PATH" >&2
  exit 1
}
[[ -f "$VOLUME_ICON" ]] || {
  echo "error: volume icon missing: $VOLUME_ICON (run scripts/generate-app-icon.sh)" >&2
  exit 1
}

mkdir -p "$STAGING" "$MOUNT_ROOT" "$(dirname "$DMG_PATH")"
cp -R "$APP_PATH" "$STAGING/Foghorn.app"
ln -s /Applications "$STAGING/Applications"

# Read-write image so we can set volume icon + Finder layout.
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$RW_DMG" >/dev/null

ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen -mountroot "$MOUNT_ROOT" "$RW_DMG")"
ATTACHED_DEV="$(echo "$ATTACH_OUT" | awk 'NR==1 {print $1}')"
VOLUME_PATH="$MOUNT_ROOT/$VOLUME_NAME"

if [[ ! -d "$VOLUME_PATH" ]]; then
  # Fallback: parse mount point from hdiutil output.
  VOLUME_PATH="$(echo "$ATTACH_OUT" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
fi
[[ -d "$VOLUME_PATH" ]] || {
  echo "error: failed to locate mounted volume" >&2
  echo "$ATTACH_OUT" >&2
  exit 1
}

cp "$VOLUME_ICON" "$VOLUME_PATH/.VolumeIcon.icns"
if command -v SetFile >/dev/null; then
  SetFile -a C "$VOLUME_PATH"
else
  # Xcode CLT may expose SetFile under DEVELOPER_DIR.
  DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
  if [[ -x "${DEVELOPER_DIR}/usr/bin/SetFile" ]]; then
    "${DEVELOPER_DIR}/usr/bin/SetFile" -a C "$VOLUME_PATH"
  else
    echo "warning: SetFile not found; volume icon may not display until custom-icon bit is set" >&2
  fi
fi

# Optional Finder icon layout (can hang without Automation permission).
# Enable with ONLINE_DMG_LAYOUT=1. Skipped by default and in CI.
if [[ "${ONLINE_DMG_LAYOUT:-}" == "1" && -z "${CI:-}" ]]; then
  perl -e 'alarm shift; exec @ARGV' 15 osascript <<OSA >/dev/null 2>&1 || true
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 740, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "Foghorn.app" of container window to {160, 190}
    set position of item "Applications" of container window to {460, 190}
    update without registering applications
    delay 0.5
    close
  end tell
end tell
OSA
fi

# Ensure Finder metadata is flushed before detach.
sync
hdiutil detach "$ATTACHED_DEV" -quiet
ATTACHED_DEV=""

rm -f "$DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null

echo "Packaged DMG: $DMG_PATH"
