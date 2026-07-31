# Online

[![CI](https://github.com/Jubblin/online/actions/workflows/ci.yml/badge.svg)](https://github.com/Jubblin/online/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)

A native macOS menu bar app that monitors **real** internet connectivity and alerts you when the connection drops. Stays subtle when everything works.

macOS can show Wi‑Fi as connected while pages fail to load — router issues, ISP outages, captive portals, and DNS failures all leave the system indicator green. **Online** probes your network in layers and only surfaces alerts when something is actually wrong.

## Why Online?

| macOS indicator | Online |
|-----------------|--------|
| Link up (Wi‑Fi/Ethernet) | Layered reachability probes |
| No failure attribution | Router, DNS, ISP, captive portal, custom host |
| Silent failures | Notification on confirmed outage + restore |
| No history | JSON outage log with timestamps |

**Alert-first by design** — the opposite of menu bar clutter. You forget it exists until your VPN dies mid-call and macOS never told you.

## Features

- **Layered Sentinel probes** — `NWPathMonitor`, gateway TCP reachability via `NWConnection`, DNS lookup, HTTP HEAD (`captive.apple.com` + `cloudflare.com`), optional custom hosts
- **Smart debouncing** — 15s evaluation window, 15s wake-from-sleep grace, 2-tick recovery confirmation, 3-tick rapid outage detection
- **Failure attribution** — know whether it's your router, DNS, ISP, captive portal, or a custom endpoint
- **Outage log viewer** — sortable in-app table; copy JSON or open file in Finder
- **Menu bar visibility** — hide the icon in Settings; monitoring and alerts continue
- **Battery-aware** — longer poll intervals on battery power
- **Launch at login** — via `SMAppService`
- **Native Swift/SwiftUI** — macOS 14+, no Electron, no dependencies

## Screenshots

**Healthy — menu bar popover**

![Online menu bar popover showing healthy status](docs/screenshots/menu-bar-healthy.png)

**Traffic-light states** — green (online), yellow (degraded), red (offline), gray (recovering)

![Traffic-light menu bar icons for all connectivity states](docs/screenshots/traffic-lights.png)

## Install

### From GitHub Releases (recommended)

1. Download the DMG for your Mac from [Releases](https://github.com/Jubblin/online/releases):
   - Apple Silicon: `Online-<version>-arm64.dmg`
   - Intel: `Online-<version>-amd64.dmg`
2. Open the DMG and drag **Online** to Applications
3. Launch Online and grant notification permission when prompted

> Signed and notarized DMGs are published when repo signing secrets are configured. Otherwise releases are unsigned — right-click → Open on first launch (see [Signing](#signing)).

### Build from source

**Requirements:** macOS 14 Sonoma or later, Xcode 15+

```bash
git clone https://github.com/Jubblin/online.git
cd online
open Online.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Online.xcodeproj -scheme Online -configuration Release build
# App: build/Build/Products/Release/Online.app

chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh Release arm64   # or amd64
# DMG: build/Online-<version>-arm64.dmg
```

## Usage

1. **Online** appears in the menu bar (subtle when healthy)
2. Click the icon to see current status, last probe time, and the most recent outage
3. Open **Settings** to configure:
   - **Show in menu bar** — hide the icon while keeping probes running (re-open Settings from the app menu if hidden)
   - **Polling interval** — 2s, 5s, 10s, or 30s (doubles on battery, capped at 8s)
   - **Custom hosts** — hostnames probed via HTTPS HEAD (e.g. work VPN endpoint)
   - **Launch at login**
4. **View outage log…** from the menu or Settings for full history in a table

Notifications fire on **confirmed outage** and when connectivity **restores**.

## How it works

```
ProbeEngine (2s tick, battery backoff)
  ├── PathProbe        NWPathMonitor — interface up?
  ├── GatewayProbe     SCDynamicStore resolver + TCP reachability (NWConnection)
  ├── DNSProbe         Resolve cloudflare.com
  ├── HTTPProbe        HEAD captive.apple.com + cloudflare.com
  └── CustomHostProbe  User-defined hosts

ConnectivityStateMachine
  ├── 15s evaluation window
  ├── 15s wake grace (suppress sleep/wake blips)
  └── States: Healthy → Degraded → Outage → Recovering

Outputs
  ├── MenuBarExtra UI (alert-first)
  ├── UserNotifications
  └── OutageLog (JSON on disk)
```

### Connectivity states

| State | Menu bar | Alerts |
|-------|----------|--------|
| Healthy | Subtle green dot | None |
| Degraded | Warning icon | None |
| Outage | Wi‑Fi slash | Notification |
| Recovering | Spinner | None |

## Development

```bash
# Run the full local health stack (lint, shellcheck, build, test)
chmod +x scripts/health.sh
./scripts/health.sh

# Or run unit tests only
xcodebuild test \
  -project Online.xcodeproj \
  -scheme Online \
  -configuration Debug \
  -destination 'platform=macOS'

# Bump version locally (CI does this on PRs)
./scripts/bump-version.sh patch
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for PR workflow, version labels, and code guidelines.

### Project structure

```
Online/
  Probes/     PathProbe, GatewayProbe, DNSProbe, HTTPProbe, ProbeEngine
  State/      ConnectivityStateMachine
  Services/   AlertService, OutageLog, WakeObserver, LaunchAtLoginService
  Models/     ProbeResult, ConnectivityState, AppSettings
  Views/      MenuBarView, SettingsView
OnlineTests/  State machine, snapshot, HTTP mock tests
scripts/      build-dmg.sh, build-signed-dmg.sh, resolve-release-arch.sh, bump-version.sh, health.sh
```

## CI / Release

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [CI](.github/workflows/ci.yml) | Push to `main`, PRs | Test + build Release artifact |
| [Release dispatch](.github/workflows/release-dispatch.yml) | Manual | Finalize CHANGELOG + tag `v*` |
| [Release](.github/workflows/release.yml) | Tag `v*` | Signed/notarized DMG → GitHub Release |
| [Release Store](.github/workflows/release-store.yml) | Tag `v*` or manual | Upload to TestFlight |
| [Version bump](.github/workflows/version-bump.yml) | PR to `main` | Auto-bump semver + build number |

**Cut a release:** Actions → **Release dispatch** on `main`, or see [docs/RELEASE.md](docs/RELEASE.md).

**PR version labels:** `version:patch` (default), `version:minor`, `version:major`

[Renovate](https://github.com/apps/renovate) keeps GitHub Actions up to date ([`renovate.json`](renovate.json)).

## Signing

CI can produce Developer ID signed and notarized DMGs when [signing secrets](docs/RELEASE.md#ci-signing-secrets) are configured. For local distribution:

```bash
./scripts/build-signed-dmg.sh Release arm64   # requires DEVELOPMENT_TEAM + cert in keychain
./scripts/build-signed-dmg.sh Release amd64
# or unsigned:
./scripts/build-dmg.sh Release arm64
./scripts/build-dmg.sh Release amd64
```

## Roadmap

All items from the initial roadmap are shipped. See [TODOS.md](TODOS.md) for future ideas.

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
