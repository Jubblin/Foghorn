#!/usr/bin/env bash
# Extract the Keep a Changelog [Unreleased] section from CHANGELOG.md.
set -euo pipefail

CHANGELOG="${1:-CHANGELOG.md}"
HEADER="## [Unreleased]"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "missing $CHANGELOG" >&2
  exit 1
fi

found=false
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^##\ \[ ]]; then
    if [[ "$line" == "$HEADER" ]]; then
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
