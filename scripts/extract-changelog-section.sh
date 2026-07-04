#!/usr/bin/env bash
# Extract a Keep a Changelog version section (## [VERSION] ...) from CHANGELOG.md.
set -euo pipefail

usage() {
  echo "usage: $0 VERSION [CHANGELOG.md]" >&2
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage

VERSION="$1"
CHANGELOG="${2:-CHANGELOG.md}"
HEADER="## [${VERSION}]"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "missing $CHANGELOG" >&2
  exit 1
fi

found=false
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^##\ \[ ]]; then
    if [[ "$line" == "${HEADER}"* ]]; then
      found=true
      printf '%s\n' "$line"
      continue
    fi
    if $found; then
      break
    fi
  elif $found; then
    printf '%s\n' "$line"
  fi
done < "$CHANGELOG"

if ! $found; then
  echo "no section for ${HEADER} in ${CHANGELOG}" >&2
  exit 1
fi
