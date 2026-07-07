#!/usr/bin/env bash
# Print MARKETING_VERSION from the Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/Online.xcodeproj/project.pbxproj"

grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+);/\1/'
