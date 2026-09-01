# Contributing to Foghorn

Thanks for your interest in improving Foghorn. This is a small native macOS app;
focused PRs are easier to review than large rewrites.

## Before You Start

- Read the [README](README.md) for architecture and build instructions
- Check [open issues](https://github.com/Jubblin/Foghorn/issues) for planned work
- For larger changes, open an issue first to discuss approach

## Development Setup

**Requirements:** macOS 14+, Xcode 15+

```bash
git clone https://github.com/Jubblin/Foghorn.git
cd online
open Foghorn.xcodeproj
```

Run tests from the command line:

```bash
xcodebuild test \
  -project Foghorn.xcodeproj \
  -scheme Foghorn \
  -configuration Debug \
  -destination 'platform=macOS'
```

### Local quality checks

CI runs SwiftLint and ShellCheck before tests. Match that locally before opening a PR:

```bash
brew install swiftlint shellcheck   # once
chmod +x scripts/health.sh
./scripts/health.sh                 # lint + shellcheck + build + test
```

Or run individual checks (also documented in [CLAUDE.md](CLAUDE.md)):

```bash
swiftlint lint --quiet
shellcheck scripts/*.sh
```

## Pull Request Process

1. Fork the repository and create a branch from `main`
2. Make your changes with clear commit messages ([Conventional Commits](https://www.conventionalcommits.org/) encouraged):
   - `feat:` new feature
   - `fix:` bug fix
   - `test:` tests only
   - `docs:` documentation
   - `chore:` tooling, CI, version bumps
3. Ensure tests pass locally
4. Open a PR against `main`

### Version bumps

Do **not** manually edit version numbers in `project.pbxproj`. The [version bump workflow](.github/workflows/version-bump.yml) handles this on PRs:

| Label | Semver bump |
|-------|-------------|
| *(none)* | patch (default on PR open) |
| `version:patch` | patch |
| `version:minor` | minor |
| `version:major` | major |

Each new commit on the PR increments the build number automatically.

### CI

PRs run [CI](.github/workflows/ci.yml) on `macos-26`: SwiftLint + ShellCheck (`quality` job), unit tests, UI smoke tests, then a Release build.

Semgrep in Actions is **advisory** (`continue-on-error` + `semgrep ci || true`) and must not gate merge. If the Semgrep GitHub App check (`semgrep-cloud-platform/scan`) is enabled, keep **Fail Open** on in Semgrep Managed Scans and leave that check **non-required** in branch protection so a stuck/failed App scan cannot block the PR.

## Code Guidelines

- Match existing Swift style and file layout (`Foghorn/Probes/`, `Foghorn/State/`, etc.)
- Prefer small, testable units; add XCTest coverage for state machine and probe logic
- Keep the **alert-first** product goal: invisible when healthy, loud when broken
- No new dependencies unless discussed in an issue first (project currently has zero SPM packages)

## Project Layout

```
Foghorn/           App target
  Probes/         Network probe implementations
  State/          ConnectivityStateMachine
  Services/       Alerts, outage log, wake observer
  Models/         Shared types
  Views/          SwiftUI menu bar and settings
FoghornTests/      Unit tests
FoghornUITests/    UI smoke tests (XCUITest)
scripts/          build-dmg.sh, bump-version.sh, extract-changelog-section.sh, health.sh
.github/          Workflows, issue/PR templates
```

## Changelog

User-facing changes should be noted in [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`.

### Releasing

GitHub Releases are created when you push a `v*` tag. The release body is taken from the matching `CHANGELOG.md` section (see [release workflow](.github/workflows/release.yml)).

Before tagging:

1. Move `[Unreleased]` entries into a new `## [X.Y.Z] - YYYY-MM-DD` section (version should match the tag without the `v` prefix).
2. Leave `[Unreleased]` empty (or remove empty subsection headings).
3. Push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`

Preview the section locally:

```bash
./scripts/extract-changelog-section.sh 0.2.1
```

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Be respectful and constructive.

## Questions

Open a [GitHub issue](https://github.com/Jubblin/Foghorn/issues/new/choose) using the bug or feature template, or start with a short description if neither fits.
