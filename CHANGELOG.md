# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.2.26] - 2026-08-03

### Added

- PATH probe row shows active interfaces (e.g. `via en4/wired`); GATEWAY shows router address; path flips logged via OSLog ([#48](https://github.com/Jubblin/online/issues/48))
- Settings option to include pre-release / continuous `-build` updates from GitHub Releases ([#50](https://github.com/Jubblin/online/issues/50))
- Remembers tab: **View outage log…** opens the log window and shows the selectable outages.json path

### Changed

- Settings window uses a tab per section (Interrupt, Checks, Remembers, Help) instead of a stacked scroll ([#46](https://github.com/Jubblin/online/issues/46))
- DESIGN.md Settings notes: battery helper is max **8s** (not 8×); not-determined alerts use **Enable alerts**
### Fixed

### Removed


## [0.2.24] - 2026-08-02

### Added

### Changed

### Fixed

- Reuse the CI signing keychain across arm64/amd64 builds so both DMGs get Developer ID + notarization ([#39](https://github.com/Jubblin/online/issues/39))

### Removed


## [0.2.23] - 2026-08-02

### Added

### Changed

### Fixed

- CI Developer ID archive uses explicit `Developer ID Application` identity so signed DMGs no longer fall back to adhoc ([#39](https://github.com/Jubblin/online/issues/39))

### Removed


## [0.2.22] - 2026-08-02

### Added

- Docs for unsigned-DMG Gatekeeper “damaged” symptom and `xattr -cr` workaround ([#38](https://github.com/Jubblin/online/issues/38))
- Auto-update checks against GitHub Releases (daily + manual); opens arch-specific DMG when a newer official release exists ([#41](https://github.com/Jubblin/online/issues/41))

### Changed

- Privacy policy documents optional GitHub Releases update checks

### Fixed

### Removed


## [0.2.20] - 2026-08-01

### Added

### Changed

### Fixed

- Gateway probe prefers `NWPath.gateways` over LAN TCP so Local Network privacy no longer false-fails the router check

### Removed


## [0.2.18] - 2026-07-31

### Added

- App icon (Abyss + Truth Green sentinel) and DMG volume icon under `packaging/`
- Continuous release workflow (`release-on-main.yml`) — tags `vX.Y.Z-build.N` after green CI on `main` and publishes prerelease DMGs
- `read-build-number.sh` and `extract-changelog-unreleased.sh` release helper scripts
- Signed DMG pipeline (`build-signed-dmg.sh`) with optional notarization via App Store Connect API
- TestFlight upload workflow (`release-store.yml`) and `upload-testflight.sh`
- Release helper scripts: `read-marketing-version.sh`, `changelog-has-unreleased-content.sh`, `finalize-changelog.sh`, `ci-setup-keychain.sh`
- `PrivacyInfo.xcprivacy` (no tracking; UserDefaults + file timestamp API reasons)
- `docs/privacy.html` for GitHub Pages hosting
- `docs/APP_REVIEW_NOTES.md` for Mac App Store submission
- `OnlineUITests` XCUITest target with eight Settings/outage-log smoke tests
- `UITestConfiguration` launch-argument harness (`-ui_testing`, open Settings/outage log, mock notifications)
- Accessibility identifiers on Settings and outage log empty state
- `docs/RELEASE.md`, `docs/PRE_RELEASE_CHECKLIST.md`, and `docs/UI_TESTING.md`
- CI `ui-test` job on `macos-26` runners
- Shared `Online.xcscheme` including unit and UI test targets

### Changed

- Version bump **requires** `VERSION_BUMP_TOKEN` (no `GITHUB_TOKEN` fallback) so bump commits cannot reintroduce the bot PR approval gate
- GitHub Release DMGs include an Applications shortcut, volume icon, and Finder icon layout for drag-to-install
- GitHub Releases publish separate versioned DMGs for Apple Silicon (`arm64`) and Intel (`amd64`) instead of a single `Online.dmg`
- CI/release workflows use repo-owned Xcode setup action (org allowlist compliance)
- Export compliance: `ITSAppUsesNonExemptEncryption` = NO in generated Info.plist
- Gateway probe now uses `SCDynamicStore` + `NWConnection` (sandbox-compatible) instead of `/sbin/route` and `/sbin/ping`
- App Sandbox enabled in `Online.entitlements`
- Settings notification permission can be enabled explicitly from Settings (Enable alerts)
- Settings layout compacts to four sections without outer scroll; Help links on one line
- Notification permission is requested on first confirmed outage instead of at launch (alert-first UX)
- Healthy menu bar icon uses near-zero opacity (0.25) per Layered Sentinel spec

### Fixed

- Release dispatch pushes changelog finalize with `VERSION_BUMP_TOKEN` so protected `main` accepts the release commit
- UI tests open Settings via explicit test window (fixes headless CI; `showSettingsWindow:` was unreliable)
- Menu bar Settings row in popover (`openSettings` instead of broken `SettingsLink`)
- Renovate configuration invalid `:separateMajorMinor` preset
- SwiftLint warnings in app sources and tests


## [0.2.1] - 2026-07-02

### Fixed

- Gateway probe now uses ICMP ping instead of TCP to ports 80/443, avoiding false `routerUnreachable` outages on routers without a web UI
- Menu bar visibility binding no longer triggers an infinite SwiftUI render loop that pinned the main thread
- Menu bar app no longer quits when the transient menu closes
- Outages that were still ongoing at quit are adopted on startup so recovery records a real ended time

## [0.2.0] - 2026-07-02

### Added

- Menu bar visibility toggle — hide icon while probes and notifications keep running
- Outage log viewer window with sortable table (started, ended, duration, failure, probes)
- Copy JSON and reveal log file in Finder from outage log window
- `probeSummary` on outage records (backward compatible with existing JSON)
- Traffic-light menu bar icons (green / yellow / red / gray `circle.fill`)

## [0.1.0] - 2026-07-01

### Added

- Native macOS 14+ menu bar app (Swift / SwiftUI)
- Layered connectivity probes: NWPathMonitor, gateway TCP, DNS, HTTP HEAD (`captive.apple.com`, `cloudflare.com`), custom hosts
- Debounced state machine with 15s evaluation window, 15s wake grace, recovery confirmation
- User notifications on confirmed outage and restore
- JSON outage log at `~/Library/Application Support/Online/outages.json`
- Settings: polling interval, custom hosts, launch at login (`SMAppService`)
- Battery-aware probe interval backoff
- Unit tests for state machine, probe snapshots, and HTTP probe mocks
- `scripts/build-dmg.sh` for unsigned release builds
- GitHub Actions: CI (test + build), release on `v*` tags, version bump on PRs
- Renovate config for GitHub Actions updates

[Unreleased]: https://github.com/Jubblin/online/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/Jubblin/online/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/Jubblin/online/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Jubblin/online/releases/tag/v0.1.0
