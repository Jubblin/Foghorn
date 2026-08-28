#!/usr/bin/env bash
# Sync root documentation into docs/ so GitHub Pages (/docs) mirrors the repo.
# Root files remain canonical. Run after editing root docs; CI uses --check.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/docs"
REPO_BLOB="https://github.com/Jubblin/Foghorn/blob/main"
CHECK_ONLY=0

if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--check]" >&2
  exit 2
fi

# Root markdown published on the docs site (basename → site path under docs/).
DOCS=(
  README.md
  DESIGN.md
  CONTRIBUTING.md
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  SECURITY.md
  PRIVACY.md
  TODOS.md
  CLAUDE.md
)

rewrite_for_site() {
  local src="$1"
  # Paths that live under docs/ in the repo become same-directory links on Pages.
  # Repo-only paths outside docs/ become blob.main links so they work on github.io.
  sed -E \
    -e 's|\]\(docs/screenshots/|\]\(screenshots/|g' \
    -e 's|\]\(docs/([A-Za-z0-9._-]+\.md)(#[^)]*)?\)|](\1\2)|g' \
    -e 's|\]\(\.\./CHANGELOG\.md(#[^)]*)?\)|](CHANGELOG.md\1)|g' \
    -e 's|\]\(\.\./DESIGN\.md(#[^)]*)?\)|](DESIGN.md\1)|g' \
    -e 's|\]\(\.\./README\.md(#[^)]*)?\)|](README.md\1)|g' \
    -e 's|\]\(\.\./CONTRIBUTING\.md(#[^)]*)?\)|](CONTRIBUTING.md\1)|g' \
    -e 's|\]\(\.\./PRIVACY\.md(#[^)]*)?\)|](PRIVACY.md\1)|g' \
    -e 's|\]\(\.\./SECURITY\.md(#[^)]*)?\)|](SECURITY.md\1)|g' \
    -e 's|\]\(\.\./CODE_OF_CONDUCT\.md(#[^)]*)?\)|](CODE_OF_CONDUCT.md\1)|g' \
    -e 's|\]\(\.\./TODOS\.md(#[^)]*)?\)|](TODOS.md\1)|g' \
    -e 's|\]\(\.\./CLAUDE\.md(#[^)]*)?\)|](CLAUDE.md\1)|g' \
    -e "s|\]\(\.\./\.github/([^)]+)\)|](${REPO_BLOB}/.github/\1)|g" \
    -e "s|\]\(\.\./scripts/([^)]+)\)|](${REPO_BLOB}/scripts/\1)|g" \
    -e "s|\]\(\.\./Foghorn\.xcodeproj([^)]*)\)|](${REPO_BLOB}/Foghorn.xcodeproj\1)|g" \
    -e "s|\]\(\.github/([^)]+)\)|](${REPO_BLOB}/.github/\1)|g" \
    -e "s|\]\(scripts/([^)]+)\)|](${REPO_BLOB}/scripts/\1)|g" \
    "$src"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

failures=0
for name in "${DOCS[@]}"; do
  src="$ROOT/$name"
  dest="$SITE/$name"
  if [[ ! -f "$src" ]]; then
    echo "error: missing canonical doc $name" >&2
    exit 1
  fi
  out="$tmpdir/$name"
  rewrite_for_site "$src" >"$out"

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ ! -f "$dest" ]]; then
      echo "docs site out of sync: missing docs/$name (run scripts/sync-docs-site.sh)" >&2
      failures=1
    elif ! cmp -s "$out" "$dest"; then
      echo "docs site out of sync: docs/$name (run scripts/sync-docs-site.sh)" >&2
      failures=1
    fi
  else
    cp "$out" "$dest"
    echo "synced docs/$name"
  fi
done

# Also rewrite in-repo docs/*.md links that point outside /docs for Pages.
for path in "$SITE"/*.md; do
  base="$(basename "$path")"
  # Skip mirrors we just wrote; they already have site-safe links.
  skip=0
  for name in "${DOCS[@]}"; do
    if [[ "$base" == "$name" ]]; then
      skip=1
      break
    fi
  done
  if [[ "$skip" -eq 1 || "$base" == "index.md" ]]; then
    continue
  fi
  out="$tmpdir/native-$base"
  rewrite_for_site "$path" >"$out"
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if ! cmp -s "$out" "$path"; then
      echo "docs site out of sync: docs/$base link rewrite (run scripts/sync-docs-site.sh)" >&2
      failures=1
    fi
  else
    if ! cmp -s "$out" "$path"; then
      cp "$out" "$path"
      echo "rewrote links in docs/$base"
    fi
  fi
done

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ "$failures" -ne 0 ]]; then
    exit 1
  fi
  echo "docs site sync OK"
fi
