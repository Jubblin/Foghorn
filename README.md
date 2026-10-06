# Foghorn

[![CI](https://github.com/Jubblin/Foghorn/actions/workflows/ci.yml/badge.svg)](https://github.com/Jubblin/Foghorn/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) [![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/) [![iOS](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/ios/) [![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)

**The truth about your connection.**

macOS can show Wi‑Fi as connected while pages fail to load — router issues, ISP outages, captive portals, and DNS failures all leave the system indicator green. Foghorn probes your network in layers and only surfaces an alert when something is actually wrong. Silent in clear weather. Impossible to miss in the fog.

**Docs site:** [jubblin.github.io/Foghorn](https://jubblin.github.io/Foghorn/) (same guides as this repo).

## Why Foghorn?

| macOS indicator          | Foghorn                                       |
| ------------------------ | ---------------------------------------------- |
| Link up (Wi‑Fi/Ethernet) | Layered reachability probes                    |
| No failure attribution   | Router, DNS, ISP, captive portal, custom host  |
| Silent failures          | Notification on confirmed outage + restore     |
| No history                | JSON outage log with timestamps                |

**Alert-first by design** — the opposite of menu bar clutter. You forget it exists until your VPN dies mid-call and macOS never told you.

## Features

- **Layered Sentinel probes** — `NWPathMonitor`, gateway via `NWPath.gateways` (TCP fallback), DNS lookup, HTTPS HEAD (`captive.apple.com/hotspot-detect.html` + `cloudflare.com`), optional custom hosts
- **Smart debouncing** — 15s evaluation window, 15s wake-from-sleep grace, 2-tick recovery confirmation, 3-tick rapid outage detection
- **Failure attribution** — know whether it's your router, DNS, ISP, captive portal, or a custom endpoint
- **Outage log viewer** — sortable in-app table; copy JSON or open file in Finder
- **Menu bar visibility** — hide the icon in Settings; monitoring and alerts continue
- **Battery-aware** — on battery the poll interval is adjusted and capped at 8s (2s→4s, 5s→7.5s, 10s/30s→8s)
- **Launch at login** — via `SMAppService`
- **Automatic updates** — signed Sparkle appcast, with an optional pre-release channel
- **iPhone app** — the same probes on iOS 17+, with background monitoring (see [iPhone](#iphone))
- **Native Swift/SwiftUI** — macOS 14+ / iOS 17+, no Electron, one dependency (Sparkle, for macOS updates)

## Screenshots

**Healthy — menu bar popover**

![Foghorn menu bar popover showing healthy status](docs/screenshots/menu-bar-healthy.png)

**Traffic-light states** — green (online), amber (degraded), red (offline), gray (recovering)

![Traffic-light menu bar icons for all connectivity states](docs/screenshots/traffic-lights.png)

## Install

### From GitHub Releases (recommended)

1. Download the DMG for your Mac from [Releases](https://github.com/Jubblin/Foghorn/releases):
   - Apple Silicon: `Foghorn-<version>-arm64.dmg`
   - Intel: `Foghorn-<version>-amd64.dmg`
2. Open the DMG and drag **Foghorn** onto **Applications**
3. Launch Foghorn and grant notification permission when prompted

**Signing status:** Released DMGs are Developer ID signed and notarized, and open normally. Builds you make yourself with `build-dmg.sh` are unsigned, and Apple Silicon Gatekeeper may show:
> "Foghorn" is damaged and can't be opened. You should move it to the Bin.

Right-click → Open does **not** fix that for unsigned downloads. Clear quarantine after install (local workaround only):

```
xattr -cr /Applications/Foghorn.app
```

Then launch Foghorn again, or build with `build-signed-dmg.sh` if you have a Developer ID certificate. Details: [docs/RELEASE.md](docs/RELEASE.md#unsigned-dmgs-and-gatekeeper).

### Build from source

**Requirements:** macOS 14 Sonoma or later, Xcode 15+ (the `FoghorniOS` scheme builds the iPhone app)

```
git clone https://github.com/Jubblin/Foghorn.git
cd Foghorn
open Foghorn.xcodeproj
```

Or from the command line:

```
xcodebuild -project Foghorn.xcodeproj -scheme Foghorn -configuration Release build
# App: build/Build/Products/Release/Foghorn.app

chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh Release arm64   # or amd64
# DMG: build/Foghorn-<version>-arm64.dmg
```

## Usage

1. **Foghorn** appears in the menu bar (subtle when healthy)
2. Click the icon for the current status and last probe time. The popover stays quiet when
   nothing is wrong: probe rows retire five minutes after the connection settles, and a
   recovered outage drops off an hour after it ends. Both come straight back when something
   fails.
3. Open **Settings** from the popover to configure:
   - **Interrupt** — show in menu bar, appearance, notification permission status
   - **Checks** — poll interval (2s, 5s, 10s, 30s; on battery 2s→4s, 5s→7.5s, and 10s/30s→8s)
     and custom hosts probed via HTTPS HEAD
   - **Remembers** — launch at login, and update behaviour including the pre-release channel
   - **Help** — Privacy, Docs, Support and Report links, version and build, and the outage log
4. **View outage log…** in Settings → Help for the full history in a table

If you hide the menu bar icon, Settings is no longer reachable from it — Foghorn runs as an
accessory app with no app menu. Reopen it with:

```
open -a Foghorn --args -open-settings
```

Notifications fire on **confirmed outage** and when connectivity **restores**.

### iPhone

The `FoghorniOS` target runs the same probes and state machine on iOS 17+. Builds are uploaded
to TestFlight by the [Release Store](.github/workflows/release-store.yml) workflow; it is not on
the App Store yet.

- **Home** — current status, last check, probe rows, last outage, and **Check now**
- **Settings** — Checks, Interrupt, and Help tabs (no Remembers tab; launch at login and updates
  are macOS-only)
- **Background monitoring** — iOS suspends the foreground probe loop, so Foghorn alerts on
  link-level changes via `NWPathMonitor` and requests a `BGAppRefreshTask` deep probe
  (gateway/DNS/HTTP) about every 15 minutes. iOS decides when that actually runs. If the app
  wasn't running in the background, the home screen says monitoring was paused.

## How it works

```
ProbeEngine (2s default tick, 8s cap on battery)
  ├── PathProbe        NWPathMonitor — interface up?
  ├── GatewayProbe     SCDynamicStore + NWPath.gateways (TCP fallback)
  ├── DNSProbe         Resolve cloudflare.com
  ├── HTTPProbe        HEAD captive.apple.com/hotspot-detect.html + cloudflare.com
  └── CustomHostProbe  User-defined hosts

ConnectivityStateMachine
  ├── 15s evaluation window
  ├── 15s wake grace (suppress sleep/wake blips)
  └── States: Healthy → Degraded → Outage → Recovering

Outputs
  ├── NSStatusItem popover (alert-first; macOS)
  ├── IOSHomeView + BackgroundMonitor (iOS)
  ├── UserNotifications
  └── OutageLog (JSON on disk)
```

### Connectivity states

The menu bar icon is always a filled dot; the colour carries the meaning.

| State      | Menu bar   | Alerts       |
| ---------- | ---------- | ------------ |
| Healthy    | Green dot  | None         |
| Degraded   | Amber dot  | None         |
| Outage     | Red dot    | Notification |
| Recovering | Gray dot   | None         |

## Development

```
# Run the full local health stack (lint, shellcheck, build, test)
chmod +x scripts/health.sh
./scripts/health.sh

# Or run unit tests only
xcodebuild test \
  -project Foghorn.xcodeproj \
  -scheme Foghorn \
  -configuration Debug \
  -destination 'platform=macOS'

# iOS unit tests (simulator)
xcodebuild test \
  -project Foghorn.xcodeproj \
  -scheme FoghorniOS \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:FoghorniOSTests

# Bump version locally (CI does this on PRs)
./scripts/bump-version.sh patch
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for PR workflow, version labels, and code guidelines.

### Project structure

```
Foghorn/
  FoghornApp.swift, AppCoordinator.swift   macOS entry point; shared probe → state wiring
  Probes/     PathProbe, GatewayProbe, GatewayResolver, DNSProbe, HTTPProbe,
              CustomHostProbe, ProbeEngine
  State/      ConnectivityStateMachine
  Services/   AlertService, OutageLog, WakeObserver, LaunchAtLoginService,
              StatusItemController (menu bar + popover), AppUpdateService (Sparkle),
              AppUpdateModels, GitHubReleaseClient
  Models/     ProbeResult, ConnectivityState, OutageRecord, AppSettings, AppLinks
  Views/      MenuBarView, SettingsView, SettingsChrome, Settings{Checks,Interrupt,HelpPrivacy}Section,
              OutageLogView
  Design/     DesignTokens (colours, fonts per DESIGN.md)
  Fonts/      Instrument Sans, JetBrains Mono
  iOS/        FoghorniOSApp, IOSHomeView, IOSSettingsView, BackgroundMonitor(+Support)
  UITest/     UITestConfiguration
FoghornTests/    macOS unit tests (state machine, probes, outage record, updates, launch at login)
FoghornUITests/  Settings and popover smoke tests
FoghorniOSTests/ iOS unit tests (shared logic + background monitoring)
scripts/      build-dmg.sh, build-signed-dmg.sh, package-dmg.sh, resolve-release-arch.sh,
              bump-version.sh, health.sh, sync-docs-site.sh, changelog helpers,
              Sparkle feed + TestFlight upload helpers, test-scripts.sh (tests the release scripts)
```

## CI / Release

| Workflow          | Trigger             | What it does                          |
| ------------------ | -------------------- | -------------------------------------- |
| [CI](.github/workflows/ci.yml)                             | Push to `main`, PRs | Lint, script tests, docs sync, macOS unit + UI tests, iOS unit tests, Semgrep; Release build on `main` |
| [Release on main](.github/workflows/release-on-main.yml)   | CI success on `main` | Tag `v<version>-build.<n>` and dispatch a pre-release build |
| [Release dispatch](.github/workflows/release-dispatch.yml) | Manual              | Finalize CHANGELOG + tag `v*`         |
| [Release](.github/workflows/release.yml)                   | Tag `v*` or manual  | Signed/notarized DMGs → GitHub Release + Sparkle appcast (`-build.` tags are pre-releases) |
| [Release Store](.github/workflows/release-store.yml)       | Tag `v*` or manual  | Upload macOS + iOS to TestFlight (skips `-build.` tags) |
| [Version bump](.github/workflows/version-bump.yml)         | PR to `main`        | Auto-bump semver + build number       |
| [CodeQL](.github/workflows/codeql.yml)                     | Push/PR to `main`, weekly | Actions + Swift code scanning   |

**Cut a release:** Actions → **Release dispatch** on `main`, or see [docs/RELEASE.md](docs/RELEASE.md).

**PR version labels:** `version:patch` (default), `version:minor`, `version:major`

[Renovate](https://github.com/apps/renovate) keeps GitHub Actions up to date ([`renovate.json`](renovate.json)).

## Signing

CI can produce Developer ID signed and notarized DMGs when [signing secrets](docs/RELEASE.md#ci-signing-secrets) are configured. For local distribution:

```
./scripts/build-signed-dmg.sh Release arm64   # requires DEVELOPMENT_TEAM + cert in keychain
./scripts/build-signed-dmg.sh Release amd64
# or unsigned:
./scripts/build-dmg.sh Release arm64
./scripts/build-dmg.sh Release amd64
```

Unsigned CI/local builds need the [`xattr -cr` workaround](#install) on Apple Silicon if Gatekeeper reports the app as damaged.

## Roadmap

All items from the initial roadmap are shipped. Future work is tracked in [open issues](https://github.com/Jubblin/Foghorn/issues); [TODOS.md](TODOS.md) keeps the shipped history.

## Related projects

- [Online Check](https://onmymenubar.app/online-check/) by Sindre Sorhus — alert-first HEAD probes (inspiration)
- [Pulse](https://github.com/altuzar/pulse-app) — Swift menu bar network monitor (MIT)

## Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

- [Report a bug](.github/ISSUE_TEMPLATE/bug_report.yml)
- [Request a feature](.github/ISSUE_TEMPLATE/feature_request.yml)
- [Security policy](SECURITY.md)

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) © 2026 [Jubblin](https://github.com/Jubblin)

*Foghorn was formerly named Online.*
