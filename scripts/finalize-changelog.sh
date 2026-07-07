#!/usr/bin/env bash
# Move CHANGELOG [Unreleased] bullets into ## [VERSION] - DATE.
set -euo pipefail

usage() {
  echo "usage: $0 VERSION [CHANGELOG.md]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage

VERSION="$1"
CHANGELOG="${2:-CHANGELOG.md}"
DATE="$(date +%Y-%m-%d)"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "missing $CHANGELOG" >&2
  exit 1
fi

python3 - "$VERSION" "$DATE" "$CHANGELOG" <<'PY'
import pathlib, re, sys

version, date, path = sys.argv[1:4]
text = pathlib.Path(path).read_text()
marker = "## [Unreleased]"
idx = text.find(marker)
if idx < 0:
    raise SystemExit("no [Unreleased] section")

start = idx + len(marker)
next_header = re.search(r"\n## \[", text[start:])
end = start + next_header.start() if next_header else len(text)
body = text[start:end].strip()

if not re.search(r"^- ", body, re.MULTILINE):
    raise SystemExit("[Unreleased] has no bullet entries")

if f"## [{version}]" in text:
    raise SystemExit(f"version section ## [{version}] already exists")

empty_unreleased = (
    "\n\n### Added\n\n### Changed\n\n### Fixed\n\n### Removed\n\n"
)
new_version_block = f"## [{version}] - {date}\n\n{body}\n\n"
new_text = text[:start] + empty_unreleased + new_version_block + text[end:]
pathlib.Path(path).write_text(new_text)
PY

echo "Finalized $CHANGELOG for $VERSION"
