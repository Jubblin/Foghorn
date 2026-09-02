#!/usr/bin/env bash
# Tests the release scripts that are pure logic — no Xcode, signing or network (#82).
# Everything else in scripts/ needs a real toolchain; shellcheck is the honest ceiling there.
#
# Deliberately not set -e: assertions run commands expecting non-zero exits.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/scripts"

PASSED=0
FAILED=0

pass() {
  PASSED=$((PASSED + 1))
  return 0
}

fail() {
  local message="$1"
  FAILED=$((FAILED + 1))
  echo "  FAIL  $message" >&2
  return 0
}

assert_eq() { # expected actual message
  local expected="$1" actual="$2" message="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass
  else
    fail "$message
        expected: $expected
        actual:   $actual"
  fi
  return 0
}

assert_exit() { # expected_status message command...
  local expected="$1" message="$2"
  shift 2
  "$@" >/dev/null 2>&1
  assert_eq "$expected" "$?" "$message"
  return 0
}

assert_contains() { # haystack needle message
  local haystack="$1" needle="$2" message="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass
  else
    fail "$message
        missing: $needle
        in:      $haystack"
  fi
  return 0
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A changelog with bullets under [Unreleased] and one released section.
write_changelog() { # path
  local path="$1"
  cat > "$path" <<'EOF'
# Changelog

## [Unreleased]

### Added

- Something new

### Fixed

- Something broken

## [0.4.0] - 2026-01-01

### Added

- The previous release

## [0.3.0] - 2025-12-01

### Added

- Older still
EOF
}

write_empty_unreleased_changelog() { # path
  local path="$1"
  cat > "$path" <<'EOF'
# Changelog

## [Unreleased]

### Added

### Fixed

## [0.4.0] - 2026-01-01

### Added

- The previous release
EOF
}

# Just the two keys the version scripts read, in the shape Xcode writes them.
write_pbxproj() { # path marketing_version build_number
  local path="$1" marketing="$2" build="$3"
  cat > "$path" <<EOF
// !\$*UTF8*\$!
{
	objects = {
		A1 /* Debug */ = {
			buildSettings = {
				CURRENT_PROJECT_VERSION = $build;
				MARKETING_VERSION = $marketing;
			};
		};
		A2 /* Release */ = {
			buildSettings = {
				CURRENT_PROJECT_VERSION = $build;
				MARKETING_VERSION = $marketing;
			};
		};
	};
}
EOF
}

echo "changelog-has-version-section.sh"
CHANGELOG="$TMP/changelog.md"
write_changelog "$CHANGELOG"
assert_exit 0 "finds a released version" \
  "$SCRIPTS/changelog-has-version-section.sh" "0.4.0" "$CHANGELOG"
assert_exit 1 "rejects a version that is not there" \
  "$SCRIPTS/changelog-has-version-section.sh" "9.9.9" "$CHANGELOG"
assert_exit 2 "usage error without a version" \
  "$SCRIPTS/changelog-has-version-section.sh"

echo "changelog-has-unreleased-content.sh"
assert_exit 0 "accepts bullets under [Unreleased]" \
  "$SCRIPTS/changelog-has-unreleased-content.sh" "$CHANGELOG"
write_empty_unreleased_changelog "$TMP/empty.md"
assert_exit 1 "rejects an [Unreleased] with only headings" \
  "$SCRIPTS/changelog-has-unreleased-content.sh" "$TMP/empty.md"
printf '# Changelog\n\n## [0.4.0] - 2026-01-01\n\n- Released\n' > "$TMP/no-unreleased.md"
assert_exit 1 "rejects a changelog with no [Unreleased] section" \
  "$SCRIPTS/changelog-has-unreleased-content.sh" "$TMP/no-unreleased.md"

echo "extract-changelog-unreleased.sh"
OUT="$("$SCRIPTS/extract-changelog-unreleased.sh" "$CHANGELOG")"
assert_contains "$OUT" "- Something new" "extracts the unreleased bullets"
assert_contains "$OUT" "- Something broken" "extracts every unreleased bullet"
if [[ "$OUT" == *"The previous release"* ]]; then
  fail "stops at the next version header, but included 0.4.0 content"
else
  pass
fi
assert_exit 1 "fails on a missing changelog" \
  "$SCRIPTS/extract-changelog-unreleased.sh" "$TMP/nope.md"

echo "extract-changelog-section.sh"
OUT="$("$SCRIPTS/extract-changelog-section.sh" "0.4.0" "$CHANGELOG")"
assert_contains "$OUT" "## [0.4.0]" "extracts the named section header"
assert_contains "$OUT" "- The previous release" "extracts the named section body"
if [[ "$OUT" == *"Older still"* ]]; then
  fail "stops at the following version, but included 0.3.0 content"
else
  pass
fi
assert_exit 1 "fails on a version that is not there" \
  "$SCRIPTS/extract-changelog-section.sh" "9.9.9" "$CHANGELOG"
assert_exit 1 "usage error without arguments" \
  "$SCRIPTS/extract-changelog-section.sh"

echo "finalize-changelog.sh"
FINAL="$TMP/finalize.md"
write_changelog "$FINAL"
assert_exit 0 "finalizes a release" "$SCRIPTS/finalize-changelog.sh" "0.5.0" "$FINAL"
FINAL_TEXT="$(cat "$FINAL")"
assert_contains "$FINAL_TEXT" "## [0.5.0] - " "writes the new version header"
# The bullets must have moved, not been copied.
assert_eq "1" "$(grep -c -- "- Something new" "$FINAL")" "moves each bullet exactly once"
UNRELEASED="$("$SCRIPTS/extract-changelog-unreleased.sh" "$FINAL")"
if [[ "$UNRELEASED" == *"- "* ]]; then
  fail "leaves [Unreleased] empty, but bullets remain"
else
  pass
fi
assert_exit 1 "refuses to finalize a version that already exists" \
  "$SCRIPTS/finalize-changelog.sh" "0.5.0" "$FINAL"
assert_exit 1 "refuses to finalize with nothing unreleased" \
  "$SCRIPTS/finalize-changelog.sh" "0.6.0" "$TMP/empty.md"

echo "resolve-release-arch.sh"
# A sourced helper, so run each case in its own shell.
arch_labels() { # input -> "ARCH_LABEL XCODE_ARCH"
  local input="$1"
  bash -c "source '$SCRIPTS/resolve-release-arch.sh'; resolve_release_arch '$input' && echo \"\$ARCH_LABEL \$XCODE_ARCH\""
  return 0
}
assert_eq "arm64 arm64" "$(arch_labels arm64)" "arm64 resolves"
assert_eq "arm64 arm64" "$(arch_labels aarch64)" "aarch64 is an alias for arm64"
assert_eq "amd64 x86_64" "$(arch_labels amd64)" "amd64 resolves to the Xcode name"
assert_eq "amd64 x86_64" "$(arch_labels x86_64)" "x86_64 is an alias for amd64"
assert_eq "amd64 x86_64" "$(arch_labels x64)" "x64 is an alias for amd64"
assert_exit 1 "rejects an unsupported architecture" \
  bash -c "source '$SCRIPTS/resolve-release-arch.sh'; resolve_release_arch riscv"

echo "read-marketing-version.sh / read-build-number.sh"
PROJECT="$TMP/project.pbxproj"
write_pbxproj "$PROJECT" "1.2.3" "42"
assert_eq "1.2.3" "$(PBXPROJ="$PROJECT" "$SCRIPTS/read-marketing-version.sh")" "reads the marketing version"
assert_eq "42" "$(PBXPROJ="$PROJECT" "$SCRIPTS/read-build-number.sh")" "reads the build number"

echo "bump-version.sh"
bump() { # marketing build type -> "version build"
  local marketing="$1" build="$2" bump_type="$3"
  write_pbxproj "$PROJECT" "$marketing" "$build"
  PBXPROJ="$PROJECT" "$SCRIPTS/bump-version.sh" "$bump_type" >/dev/null || return 1
  echo "$(PBXPROJ="$PROJECT" "$SCRIPTS/read-marketing-version.sh") $(PBXPROJ="$PROJECT" "$SCRIPTS/read-build-number.sh")"
  return 0
}
assert_eq "1.2.4 43" "$(bump 1.2.3 42 patch)" "patch bumps the last component"
assert_eq "1.3.0 43" "$(bump 1.2.3 42 minor)" "minor resets the patch"
assert_eq "2.0.0 43" "$(bump 1.2.3 42 major)" "major resets minor and patch"
assert_eq "1.2.3 43" "$(bump 1.2.3 42 build)" "build leaves the marketing version alone"
# Two-digit components are where naive string handling breaks.
assert_eq "0.10.0 100" "$(bump 0.9.9 99 minor)" "carries 0.9.9 to 0.10.0"
assert_eq "0.9.10 100" "$(bump 0.9.9 99 patch)" "carries the patch past 9"
assert_exit 1 "rejects an unknown bump type" \
  env PBXPROJ="$PROJECT" "$SCRIPTS/bump-version.sh" sideways
assert_exit 1 "usage error without a bump type" \
  env PBXPROJ="$PROJECT" "$SCRIPTS/bump-version.sh"

echo
if [[ "$FAILED" -gt 0 ]]; then
  echo "$PASSED passed, $FAILED failed" >&2
  exit 1
fi
echo "$PASSED passed"
