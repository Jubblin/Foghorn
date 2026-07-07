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

## GitHub release (dispatch workflow)

Use **Actions → Release dispatch → Run workflow** on `main`.

1. Enter the version **without** the `v` prefix (must match `MARKETING_VERSION` on `main`, e.g. `0.2.6`).
2. Leave **Validate only** unchecked to auto-finalize the changelog and tag.

The workflow ([release-dispatch.yml](../.github/workflows/release-dispatch.yml)) will:

1. Validate `[Unreleased]` has at least one bullet (or an existing `## [VERSION]` section when validating only).
2. Validate `MARKETING_VERSION` matches the input version.
3. Move `[Unreleased]` → `## [VERSION] - YYYY-MM-DD` and commit to `main`.
4. Create and push tag `vX.Y.Z`.

Tag push triggers:

| Workflow | Artifact |
|----------|----------|
| [release.yml](../.github/workflows/release.yml) | Developer ID signed + notarized DMG → GitHub Release |
| [release-store.yml](../.github/workflows/release-store.yml) | Mac App Store archive → TestFlight |

### Validate only (dry run)

Check **Validate only — do not auto-move [Unreleased]** to run gates without committing or tagging. Use this before the real dispatch when you want to confirm version alignment and changelog state.

### Manual tag (fallback)

```bash
# After moving [Unreleased] manually in CHANGELOG.md
git tag vX.Y.Z
git push origin vX.Y.Z
```

Preview release notes locally:

```bash
./scripts/extract-changelog-section.sh X.Y.Z
```

### Prereleases

Tags containing `-` (e.g. `v1.0.0-beta.1`) are marked as GitHub prereleases automatically.

## Version alignment

- Tag `vX.Y.Z` must match `MARKETING_VERSION` in `project.pbxproj` at the tagged commit.
- Do **not** hand-edit version numbers in `project.pbxproj`; use PR labels (`version:patch`, `version:minor`, `version:major`).

## Dual distribution builds

On tag `v*`, both workflows run from the same commit:

- **GitHub** — `scripts/build-signed-dmg.sh` archives with Developer ID, notarizes the DMG, and publishes via `release.yml`. Falls back to an unsigned DMG when signing secrets are not configured.
- **App Store** — `scripts/upload-testflight.sh` archives with Apple Distribution and uploads to TestFlight via `release-store.yml`. Skips gracefully when App Store Connect API credentials are missing.

You can also trigger **Release Store** manually from Actions (useful for re-uploading a build without re-tagging).

## CI signing secrets

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|--------|---------|
| `DEVELOPMENT_TEAM` | Apple Team ID |
| `DEVELOPER_ID_CERTIFICATE_P12` | Base64 `.p12` for GitHub DMG (Developer ID Application) |
| `APP_STORE_CERTIFICATE_P12` | Base64 `.p12` for TestFlight (Apple Distribution) |
| `APPLE_CERTIFICATE_P12` | Fallback if you use one cert for both workflows |
| `P12_PASSWORD` | Export password for the `.p12` |
| `APP_STORE_CONNECT_API_KEY_ID` | API key ID (notarization + TestFlight) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | Contents of the `.p8` key file |

Without signing secrets, `release.yml` still publishes an unsigned DMG. `release-store.yml` exits successfully without uploading.
