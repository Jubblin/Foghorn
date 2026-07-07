# Releasing Online

Online ships on two channels with the **same version number**:

| Channel | Artifact | Signing |
|---------|----------|---------|
| GitHub Releases | `.dmg` | Developer ID + notarization |
| Mac App Store | TestFlight → public | Apple Distribution |

## Cadence

| Rhythm | Action |
|--------|--------|
| Every PR merge | CI runs lint, unit tests, UI smoke tests, Release build |
| Every 1–2 weeks (or when `[Unreleased]` is meaningful) | GitHub release via tag |
| During pre-store hardening | Weekly TestFlight internal builds |
| After TestFlight soak (3–7 days) | Promote same version to App Store |

## Before you release

1. Ensure `[Unreleased]` in [CHANGELOG.md](../CHANGELOG.md) has user-facing bullets.
2. Ensure `MARKETING_VERSION` on `main` matches the version you are about to ship (set by the version-bump bot on the merging PR).
3. Run [PRE_RELEASE_CHECKLIST.md](PRE_RELEASE_CHECKLIST.md) on a Release build locally.
4. Run `./scripts/health.sh` (or rely on green CI).

## Hosting the privacy policy (one-time)

1. Repo **Settings → Pages**
2. Source: **Deploy from branch** → `main` → `/docs`
3. Verify https://jubblin.github.io/online/privacy.html loads

This URL is used in App Store Connect and in-app Help links.

## GitHub release (today)

1. Move `[Unreleased]` entries into `## [X.Y.Z] - YYYY-MM-DD` (version matches tag without `v`).
2. Push the tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

3. [release.yml](../.github/workflows/release.yml) builds the DMG and publishes release notes from CHANGELOG.

Preview notes locally:

```bash
./scripts/extract-changelog-section.sh X.Y.Z
```

### Prereleases

Tags containing `-` (e.g. `v1.0.0-beta.1`) are marked as GitHub prereleases automatically.

## GitHub release (planned — dispatch workflow)

A `workflow_dispatch` release will:

1. Validate `[Unreleased]` is non-empty.
2. Validate `MARKETING_VERSION` matches the input version.
3. Auto-move `[Unreleased]` → version section and commit.
4. Create tag `vX.Y.Z` and trigger build workflows.

## Version alignment

- Tag `vX.Y.Z` must match `MARKETING_VERSION` in `project.pbxproj` at the tagged commit.
- Do **not** hand-edit version numbers in `project.pbxproj`; use PR labels (`version:patch`, `version:minor`, `version:major`).

## Dual distribution builds (planned)

On tag `v*`:

- `release.yml` → Developer ID signed + notarized DMG for GitHub.
- `release-store.yml` → Apple Distribution archive → TestFlight.

Same source, same version; different export/signing method.
