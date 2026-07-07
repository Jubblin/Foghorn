#!/usr/bin/env bash
# Exit 0 when CHANGELOG [Unreleased] has at least one bullet.
set -euo pipefail

CHANGELOG="${1:-CHANGELOG.md}"

python3 - "$CHANGELOG" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
marker = "## [Unreleased]"
idx = text.find(marker)
if idx < 0:
    raise SystemExit("no [Unreleased] section")
start = idx + len(marker)
match = re.search(r"\n## \[", text[start:])
end = start + match.start() if match else len(text)
body = text[start:end]
if not re.search(r"^- ", body, re.MULTILINE):
    raise SystemExit("[Unreleased] has no bullet entries")
PY
