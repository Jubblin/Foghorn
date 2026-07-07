#!/usr/bin/env bash
# Exit 0 when ## [VERSION] exists in CHANGELOG.md.
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $0 VERSION" >&2; exit 2; }

VERSION="$1"
CHANGELOG="${2:-CHANGELOG.md}"
HEADER="## [${VERSION}]"

if grep -qF "$HEADER" "$CHANGELOG"; then
  exit 0
fi

exit 1
