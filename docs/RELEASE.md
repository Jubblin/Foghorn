# Releasing Online

Online ships on two channels with the **same version number**:

| Channel | Artifact | Signing |
|---------|----------|---------|
| GitHub Releases | `.dmg` | Developer ID + notarization |
| Mac App Store | TestFlight → public | Apple Distribution |

## macOS versions

Online uses **two different macOS version concepts** — do not confuse them when cutting a release.

| Context | macOS version | Where it is set |
|---------|---------------|-----------------|
| **Running the app** (customers) | **macOS 14 Sonoma or later** | `MACOSX_DEPLOYMENT_TARGET = 14.0` in `Online.xcodeproj` |
| **Building in CI** (tagged releases) | **`macos-27` GitHub Actions runners** | `runs-on:` in `ci.yml`, `release.yml`, `release-store.yml` |
| **Local signed release** (optional) | **macOS 26 Tahoe or later**; **macOS 27** when available on your Mac | Your machine + Xcode 26+ (Xcode 27 on macOS 27) |

### CI and release workflows (`macos-27`)

Tagged releases (`release.yml`, `release-store.yml`) and [CI](../.github/workflows/ci.yml) build on GitHub-hosted **`macos-27`** runners (Apple Silicon). Xcode is selected via the repo-owned [`.github/actions/setup-xcode`](../.github/actions/setup-xcode) composite action (default toolchain on the runner image).

| Workflow | Runner | What it produces |
|----------|--------|------------------|
| [ci.yml](../.github/workflows/ci.yml) | `macos-27` | Lint, unit tests, UI smoke, Release `.app` artifact |
| [release.yml](../.github/workflows/release.yml) | `macos-27` | Signed/notarized `Online-<version>-arm64.dmg` + `Online-<version>-amd64.dmg` → GitHub Release |
| [release-store.yml](../.github/workflows/release-store.yml) | `macos-27` | App Store archive → TestFlight |

**Runner labels (GitHub Actions):**

| Label | Use |
|-------|-----|
| `macos-27` | Default for this repo (ARM64) |
| `macos-27-intel` / `macos-27-large` | Intel — avoid; Apple does not ship Intel Macs on macOS 27 |

**Before `macos-27` is GA:** GitHub may still serve **`macos-26`** images. Watch [actions/runner-images](https://github.com/actions/runner-images/issues) for the macOS 27 announcement. Until then, keep `runs-on: macos-26` in workflow files; the table above is the **target** once the image ships (expected fall 2026).

**Do not use** `macos-14` — Sonoma runners began deprecation on 2026-07-06 and are unsupported for new release pipelines.

### GitHub Release notes (customer-facing text)

`release.yml` appends this footer to every published DMG release:

> **Requirements:** macOS 14 Sonoma or later

That is the **minimum OS to run Online**, not the OS used to compile the build. Do not change it to macOS 27 unless you intentionally raise `MACOSX_DEPLOYMENT_TARGET` in Xcode and ship a breaking major release.

### Local release verification

When testing a signed build before dispatch:

```bash
xcodebuild -version          # Xcode 26+ (27 on macOS 27)
sw_vers                      # macOS 26+ recommended
./scripts/build-signed-dmg.sh Release arm64   # or amd64
# DMG: build/Online-<MARKETING_VERSION>-arm64.dmg
```

Match the major Xcode/macOS generation to what CI uses when possible so archive and export behaviour stays consistent.

### Architecture-specific GitHub DMGs

[release.yml](../.github/workflows/release.yml) builds **two** Developer ID DMGs from the Apple Silicon runner (cross-compiling Intel):

| Artifact | Mac |
|----------|-----|
| `Online-<version>-arm64.dmg` | Apple Silicon |
| `Online-<version>-amd64.dmg` | Intel (x86_64) |

`<version>` is the release tag without the leading `v` (e.g. `0.2.14` or `0.2.14-build.31`). Locally, omit `RELEASE_VERSION` to use `MARKETING_VERSION` from the Xcode project.

Each DMG is packaged with:

- An **Applications** symlink for drag-to-install
- A **volume icon** (`packaging/VolumeIcon.icns`, matching the app icon)
- Optional Finder icon layout when `ONLINE_DMG_LAYOUT=1` (skipped in CI)

Regenerate icons after changing `packaging/Online-icon.svg`:

```bash
./scripts/generate-app-icon.sh
```

### Migrating workflows to `macos-27`

When GitHub announces macOS 27 runner GA:

1. Replace `runs-on: macos-26` → `runs-on: macos-27` in:
   - `.github/workflows/ci.yml` (all macOS jobs)
   - `.github/workflows/release.yml`
   - `.github/workflows/release-store.yml`
2. Merge and wait for green CI on a PR.
3. Run **Release dispatch** with **Validate only** before the first real tag on the new runners.
4. Update this section to remove the `macos-26` fallback note.

## Cadence

| Rhythm | Action |
|--------|--------|
| Every PR merge to `main` | CI runs; on success, **Release on main** tags `vX.Y.Z-build.N` and publishes a **prerelease** DMG |
| Every 1–2 weeks (or when `[Unreleased]` is meaningful) | **Release dispatch** for an official `vX.Y.Z` tag (non-prerelease) + TestFlight |
| During pre-store hardening | Weekly TestFlight internal builds via **Release dispatch** |
| After TestFlight soak (3–7 days) | Promote same version to App Store |

### Continuous releases (every merge)

After green CI on `main`, [release-on-main.yml](../.github/workflows/release-on-main.yml) creates a tag like `v0.2.9-build.24` from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, then [release.yml](../.github/workflows/release.yml) publishes a **prerelease** DMG to GitHub Releases. Release notes use the matching `## [X.Y.Z]` changelog section when present, otherwise `[Unreleased]`.

Commits with message `chore(release): …` (from **Release dispatch**) are skipped so official releases are not duplicated.

TestFlight ([release-store.yml](../.github/workflows/release-store.yml)) runs only for official `vX.Y.Z` tags, not continuous `-build.N` tags.

**Note:** Tags pushed with `GITHUB_TOKEN` do not trigger other workflows. `release-on-main` and `release-dispatch` explicitly dispatch `release.yml` (and `release-store.yml` for official releases) via `workflow_dispatch`.

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
| [release.yml](../.github/workflows/release.yml) | Developer ID signed + notarized arm64 + amd64 DMGs → GitHub Release |
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

### Avoid “workflows awaiting approval” after version bumps

GitHub holds `pull_request` workflow runs for approval when the PR update is attributed to `github-actions[bot]` ([changelog](https://github.blog/changelog/2026-06-11-bot-created-pull-requests-can-run-workflows-if-approved/)). There is **no repo setting to disable that gate**.

[Version bump](../.github/workflows/version-bump.yml) therefore **requires** repo secret `VERSION_BUMP_TOKEN` (a human/app PAT). Bumps fail closed if it is missing, instead of falling back to `GITHUB_TOKEN` and reintroducing the approval prompt.

**Setup (one-time):**

1. Create a **fine-grained PAT** scoped to this repo only with **Contents** + **Pull requests** read/write  
   (short-term: `gh auth token | gh secret set VERSION_BUMP_TOKEN` using your `gh` login).
2. Store it: `gh secret set VERSION_BUMP_TOKEN` (run locally so the value never enters chat logs).
3. Prefer a dedicated fine-grained PAT over a long-lived `gh` OAuth token; rotate if you re-auth `gh`.

**Also:** public-repo PRs that change `.github/workflows/**` can be held once for approval as potentially malicious ([changelog](https://github.blog/changelog/2026-07-28-github-actions-holds-potentially-malicious-workflows-for-approval/)). Approve those runs in the Actions **web UI** (API cannot approve that hold).

## Dual distribution builds

On tag `v*`, both workflows run from the same commit:

- **GitHub** — `scripts/build-signed-dmg.sh` archives each architecture (`arm64`, `amd64`) with Developer ID, notarizes each DMG, and publishes versioned artifacts via `release.yml`. Falls back to unsigned DMGs when signing secrets are not configured.
- **App Store** — `scripts/upload-testflight.sh` archives with Apple Distribution and uploads to TestFlight via `release-store.yml`. Skips gracefully when App Store Connect API credentials are missing.

You can also trigger **Release Store** manually from Actions (useful for re-uploading a build without re-tagging).

## CI signing secrets

Configure these in **Settings → Secrets and variables → Actions** (repo **Settings → Secrets and variables → Actions → New repository secret**).

### What each secret is for

| Secret | Used by | Required when |
|--------|---------|---------------|
| `VERSION_BUMP_TOKEN` | `version-bump.yml` | **Required** — human/app PAT so bump commits do not hit the bot approval gate |
| `DEVELOPMENT_TEAM` | All signed builds | Any signing or TestFlight upload |
| `DEVELOPER_ID_CERTIFICATE_P12` | `release.yml` (GitHub DMG) | Signed + notarized DMG |
| `APP_STORE_CERTIFICATE_P12` | `release-store.yml` (TestFlight) | App Store upload |
| `APPLE_CERTIFICATE_P12` | Either workflow | Fallback if you only export one `.p12` |
| `P12_PASSWORD` | Both signing workflows | Whenever a `.p12` secret is set |
| `APP_STORE_CONNECT_API_KEY_ID` | Notarization + TestFlight | Notarized DMG or TestFlight upload |
| `APP_STORE_CONNECT_ISSUER_ID` | Notarization + TestFlight | Same as above |
| `APP_STORE_CONNECT_API_KEY` | Notarization + TestFlight | Same as above |

Without signing secrets, `release.yml` still publishes an **unsigned** DMG. `release-store.yml` exits successfully without uploading.

### Prerequisites (one-time)

1. **Apple Developer Program** — enroll at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/) (£99/year). Approval can take up to 48 hours for new accounts.
2. **Verify membership** — [developer.apple.com/account](https://developer.apple.com/account/) → **Membership** shows **Active**.
3. **Register bundle ID** — [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → **App IDs** → explicit `com.online.menu` (must match `Online.xcodeproj`). Enable **App Sandbox**.
4. **App Store Connect app** (for TestFlight only) — [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) → **Apps** → **+** → macOS app using bundle ID `com.online.menu`.
5. **Mac with macOS 26+** (macOS 27 when available) and **Keychain Access** — certificates are created and exported locally, not in CI.

---

### `DEVELOPMENT_TEAM` — Apple Team ID

**What it is:** Your 10-character Apple Developer Team ID (e.g. `AB12CD34EF`).

**How to get it:**

1. Sign in at [developer.apple.com/account](https://developer.apple.com/account/).
2. Open **Membership details**.
3. Copy **Team ID**.

**GitHub secret value:** paste the Team ID as plain text (no quotes).

---

### `DEVELOPER_ID_CERTIFICATE_P12` — GitHub DMG signing

**What it is:** Base64-encoded PKCS#12 (`.p12`) containing your **Developer ID Application** certificate **and its private key**. Used to sign the `.dmg` for GitHub Releases.

**How to get it:**

1. **Create the certificate** (skip if already in Keychain):
   - [Certificates](https://developer.apple.com/account/resources/certificates/list) → **+**.
   - Choose **Developer ID Application** → Continue.
   - On your Mac: **Keychain Access** → **Certificate Assistant** → **Request a Certificate From a Certificate Authority**.
     - Email: your Apple ID email.
     - Common Name: e.g. `Online Developer ID`.
     - Select **Saved to disk** → save the `.certSigningRequest` file.
   - Upload the CSR → Download the `.cer` → double-click to install.
   - In Keychain Access → **My Certificates**, confirm **Developer ID Application: … (TEAMID)** appears.

2. **Export as `.p12`:**
   - Keychain Access → **My Certificates**.
   - Expand **Developer ID Application: …**.
   - Select **both** the certificate **and** the private key beneath it (⌘-click).
   - **File → Export Items…** → format **Personal Information Exchange (.p12)**.
   - Set an export password — you will store this as `P12_PASSWORD`.

3. **Base64-encode for GitHub:**

   ```bash
   base64 -i ~/Downloads/Online-DeveloperID.p12 | pbcopy
   ```

   Paste the entire output (one long line) into the secret value.

**GitHub secret value:** base64 string of the `.p12` file.

**Note:** Developer ID DMG builds do **not** need a provisioning profile. CI uses automatic signing with this certificate.

---

### `APP_STORE_CERTIFICATE_P12` — TestFlight / App Store

**What it is:** Base64-encoded `.p12` containing your **Apple Distribution** certificate **and private key**. Used to archive and upload to TestFlight.

**How to get it:**

1. **Create the certificate** (skip if already in Keychain):
   - [Certificates](https://developer.apple.com/account/resources/certificates/list) → **+**.
   - Choose **Apple Distribution** → Continue.
   - Upload a CSR (same process as Developer ID above, or reuse a saved CSR).
   - Download `.cer` → double-click to install.
   - Confirm **Apple Distribution: … (TEAMID)** in Keychain Access.

2. **Provisioning profile** (recommended before first store archive):
   - [Profiles](https://developer.apple.com/account/resources/profiles/list) → **+** → **Mac App Store Connect**.
   - App ID: `com.online.menu`.
   - Certificate: your **Apple Distribution** cert.
   - Download and double-click to install.
   - CI also passes `-allowProvisioningUpdates` so Xcode can refresh profiles if needed.

3. **Export as `.p12`** (same steps as Developer ID, but select **Apple Distribution** cert + private key).

4. **Base64-encode:**

   ```bash
   base64 -i ~/Downloads/Online-Distribution.p12 | pbcopy
   ```

**GitHub secret value:** base64 string of the `.p12` file.

---

### `APPLE_CERTIFICATE_P12` — optional fallback

**What it is:** Same format as above. Only needed if you use **one** exported `.p12` for both workflows instead of separate Developer ID and Distribution secrets.

**When to use:** Rare — only if you intentionally export a single cert. Normally set `DEVELOPER_ID_CERTIFICATE_P12` and `APP_STORE_CERTIFICATE_P12` separately.

---

### `P12_PASSWORD` — certificate export password

**What it is:** The password you chose when exporting the `.p12` from Keychain Access.

**How to get it:** You set this during **File → Export Items…** in Keychain Access. It is **not** your Apple ID password.

**GitHub secret value:** the export password as plain text.

**Important:** Use the **same** password if both `.p12` files were exported with the same password. If they differ, export both with one shared password before adding to GitHub (simplest for CI).

---

### `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY`

**What they are:** App Store Connect API credentials. Used for:

- **DMG notarization** (`xcrun notarytool` in `build-signed-dmg.sh`)
- **TestFlight upload** (`xcrun altool` in `upload-testflight.sh`)

**How to get them:**

1. Sign in at [appstoreconnect.apple.com](https://appstoreconnect.apple.com/).
2. **Users and Access** → **Integrations** → **App Store Connect API**.
3. Click **+** to generate a key:
   - **Name:** e.g. `GitHub Actions Online`
   - **Access:** **Developer** (minimum — can upload builds) or **Admin**
4. Click **Generate**.
5. **Download the `.p8` file immediately** — Apple only allows one download. Store it in a password manager.
6. On the same page, note:
   - **Issuer ID** (top of the API keys section, UUID format)
   - **Key ID** (shown in the key's row, 10 characters)

**GitHub secret values:**

| Secret | Value |
|--------|-------|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID (e.g. `AB12CD34EF`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID) |
| `APP_STORE_CONNECT_API_KEY` | **Full contents** of the `.p8` file, including `-----BEGIN PRIVATE KEY-----` / `-----END PRIVATE KEY-----` lines |

To copy the key contents:

```bash
pbcopy < ~/Downloads/AuthKey_AB12CD34EF.p8
```

**Do not** base64-encode the `.p8` — paste the raw PEM text into the secret.

---

### Add secrets to GitHub

1. Open `https://github.com/Jubblin/online/settings/secrets/actions`.
2. **New repository secret** for each name above.
3. Paste the value → **Add secret**.

**Recommended minimum setups:**

| Goal | Secrets to set |
|------|----------------|
| Unsigned GitHub DMG only | *(none — default)* |
| Signed + notarized GitHub DMG | `DEVELOPMENT_TEAM`, `DEVELOPER_ID_CERTIFICATE_P12`, `P12_PASSWORD`, `APP_STORE_CONNECT_API_KEY_*` (all three) |
| TestFlight upload | `DEVELOPMENT_TEAM`, `APP_STORE_CERTIFICATE_P12`, `P12_PASSWORD`, `APP_STORE_CONNECT_API_KEY_*` (all three) |
| Full dual distribution | All of the above |

### Verify secrets locally (optional)

After exporting certs to your Mac keychain, you can dry-run before pushing secrets:

```bash
export DEVELOPMENT_TEAM=YOUR_TEAM_ID
./scripts/build-signed-dmg.sh Release arm64    # needs Developer ID cert in keychain
./scripts/build-signed-dmg.sh Release amd64
./scripts/upload-testflight.sh Release   # needs Distribution cert + API key env vars
```

For notarization locally with the API key:

```bash
export APP_STORE_CONNECT_API_KEY_ID=...
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_API_KEY="$(cat AuthKey_XXXXX.p8)"
```

### Setup checklist

- [ ] Developer Program membership **Active**
- [ ] Team ID → `DEVELOPMENT_TEAM`
- [ ] Bundle ID `com.online.menu` registered with App Sandbox
- [ ] Developer ID Application cert exported → `DEVELOPER_ID_CERTIFICATE_P12`
- [ ] Apple Distribution cert exported → `APP_STORE_CERTIFICATE_P12`
- [ ] Export password → `P12_PASSWORD`
- [ ] App Store Connect API key downloaded → `APP_STORE_CONNECT_API_KEY_*` (all three)
- [ ] App Store Connect macOS app record created (TestFlight)
- [ ] Privacy policy live at https://jubblin.github.io/online/privacy.html
- [ ] Run **Release dispatch** with **Validate only** to confirm gates before first real release
