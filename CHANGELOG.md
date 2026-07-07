# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Release dispatch workflow (`release-dispatch.yml`) — validate gates, auto-finalize CHANGELOG, tag
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
- CI `ui-test` job (soft-fail while menu bar XCTest bootstrap stabilises)
- Shared `Online.xcscheme` including unit and UI test targets

### Changed

- CI/release workflows use repo-owned Xcode setup action (org allowlist compliance)
- Export compliance: `ITSAppUsesNonExemptEncryption` = NO in generated Info.plist
- Gateway probe now uses `SCDynamicStore` + `NWConnection` (sandbox-compatible) instead of `/sbin/route` and `/sbin/ping`
- App Sandbox enabled in `Online.entitlements`
- Settings notification permission can be enabled explicitly from Settings (Enable alerts)
- Settings layout compacts to four sections without outer scroll; Help links on one line
- Notification permission is requested on first confirmed outage instead of at launch (alert-first UX)
- Healthy menu bar icon uses near-zero opacity (0.25) per Layered Sentinel spec

### Fixed

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
