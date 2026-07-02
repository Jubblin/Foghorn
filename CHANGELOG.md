# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
