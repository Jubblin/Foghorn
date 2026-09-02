#!/usr/bin/env bash
# Print MARKETING_VERSION from the Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Overridable so tests can run against a fixture instead of the real project (#82).
PBXPROJ="${PBXPROJ:-$ROOT/Foghorn.xcodeproj/project.pbxproj}"

grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+);/\1/'
