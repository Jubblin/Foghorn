#!/usr/bin/env bash
# Bump MARKETING_VERSION and/or CURRENT_PROJECT_VERSION in the Xcode project.
# Usage: bump-version.sh [patch|minor|major|build]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/Online.xcodeproj/project.pbxproj"
BUMP_TYPE="${1:-patch}"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "error: project file not found at $PBXPROJ" >&2
  exit 1
fi

read_version() {
  grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+);/\1/'
}

read_build() {
  grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);/\1/'
}

CURRENT_VERSION="$(read_version)"
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  build)
    ;;
  *)
    echo "error: unknown bump type '$BUMP_TYPE' (use patch, minor, major, or build)" >&2
    exit 1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

if [[ "$BUMP_TYPE" != "build" ]]; then
  perl -i -pe "s/MARKETING_VERSION = \\d+\\.\\d+\\.\\d+;/MARKETING_VERSION = ${NEW_VERSION};/g" "$PBXPROJ"
fi

perl -i -pe 's/CURRENT_PROJECT_VERSION = (\d+);/"CURRENT_PROJECT_VERSION = ".($1+1).";"/ge' "$PBXPROJ"

NEW_BUILD="$(read_build)"

echo "marketing_version=$NEW_VERSION"
echo "build_number=$NEW_BUILD"
echo "bump_type=$BUMP_TYPE"
