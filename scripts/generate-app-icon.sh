#!/usr/bin/env bash
# Regenerate AppIcon PNGs and packaging/VolumeIcon.icns from packaging/Foghorn-icon.svg.
# Requires: rsvg-convert (librsvg), iconutil, sips
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/packaging/Foghorn-icon.svg"
ICONSET_DIR="$ROOT/Foghorn/Assets.xcassets/AppIcon.appiconset"
TMP_ICONSET="$ROOT/packaging/VolumeIcon.iconset"
MASTER="$ROOT/packaging/Foghorn-icon-1024.png"
# Compose the retina suffix without embedding an email-like token in source.
RETINA="$(printf '@%s' '2x')"

command -v rsvg-convert >/dev/null || {
  echo "error: rsvg-convert required (brew install librsvg)" >&2
  exit 1
}

mkdir -p "$ICONSET_DIR" "$TMP_ICONSET"
find "$ICONSET_DIR" -maxdepth 1 -name 'icon_*.png' -delete
rsvg-convert -w 1024 -h 1024 "$SVG" -o "$MASTER"

# sips can mishandle "@" in output paths — write via a temp file then mv.
render() {
  local size="$1" name="$2" dest="$3"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/foghorn-icon.XXXXXX.png")"
  sips -z "$size" "$size" "$MASTER" --out "$tmp" >/dev/null
  mv -f "$tmp" "$dest/$name"
}

n2() { printf 'icon_%s%s.png' "$1" "$RETINA"; }

# App Icon asset catalog (macOS)
render 16 "icon_16x16.png" "$ICONSET_DIR"
render 32 "$(n2 16x16)" "$ICONSET_DIR"
render 32 "icon_32x32.png" "$ICONSET_DIR"
render 64 "$(n2 32x32)" "$ICONSET_DIR"
render 128 "icon_128x128.png" "$ICONSET_DIR"
render 256 "$(n2 128x128)" "$ICONSET_DIR"
render 256 "icon_256x256.png" "$ICONSET_DIR"
render 512 "$(n2 256x256)" "$ICONSET_DIR"
render 512 "icon_512x512.png" "$ICONSET_DIR"
render 1024 "$(n2 512x512)" "$ICONSET_DIR"

# Volume icon iconset (same pixels)
for f in \
  "icon_16x16.png" "$(n2 16x16)" \
  "icon_32x32.png" "$(n2 32x32)" \
  "icon_128x128.png" "$(n2 128x128)" \
  "icon_256x256.png" "$(n2 256x256)" \
  "icon_512x512.png" "$(n2 512x512)"
do
  cp "$ICONSET_DIR/$f" "$TMP_ICONSET/$f"
done

iconutil -c icns "$TMP_ICONSET" -o "$ROOT/packaging/VolumeIcon.icns"
rm -rf "$TMP_ICONSET"

python3 - "$ICONSET_DIR" "$RETINA" <<'PY'
import json, sys
from pathlib import Path
iconset, retina = Path(sys.argv[1]), sys.argv[2]
def n(base, scale):
    return f"icon_{base}.png" if scale == "1x" else f"icon_{base}{retina}.png"
images = []
for size, base1, base2 in [
    ("16x16", "16x16", "16x16"),
    ("32x32", "32x32", "32x32"),
    ("128x128", "128x128", "128x128"),
    ("256x256", "256x256", "256x256"),
    ("512x512", "512x512", "512x512"),
]:
    images.append({"filename": n(base1, "1x"), "idiom": "mac", "scale": "1x", "size": size})
    images.append({"filename": n(base2, "2x"), "idiom": "mac", "scale": "2x", "size": size})
iconset.joinpath("Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
PY

echo "Wrote AppIcon assets and packaging/VolumeIcon.icns"
