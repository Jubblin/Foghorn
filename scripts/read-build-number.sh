#!/usr/bin/env bash
# Print CURRENT_PROJECT_VERSION from the Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/Foghorn.xcodeproj/project.pbxproj"

grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);/\1/'
