# Online

A native macOS menu bar app that monitors **real** internet connectivity and alerts you when the connection drops. The icon stays subtle when everything works.

macOS WiFi can show "connected" while pages fail to load. Online probes your network in layers and only surfaces alerts when something is actually wrong.

## Features

- **Alert-first UX** — low-opacity menu bar icon when healthy; visible icon and notification on outage
- **Layered probes** — interface path, gateway TCP, DNS resolution, HTTP HEAD (`captive.apple.com` + `cloudflare.com`), optional custom hosts
- **Debounced state machine** — 15s evaluation window, 15s wake-from-sleep grace, 2-tick recovery confirmation
- **Failure attribution** — router, DNS, ISP, captive portal, or custom host
- **Outage log** — JSON history in `~/Library/Application Support/Online/outages.json`
- **Battery-aware polling** — longer intervals on battery power
- **Launch at login** — via `SMAppService`

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+

## Build

```bash
# Open in Xcode
open Online.xcodeproj

# Or build from CLI
xcodebuild -project Online.xcodeproj -scheme Online -configuration Release build

# Run tests
xcodebuild test -project Online.xcodeproj -scheme Online -configuration Debug

# Build release DMG (unsigned by default)
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh Release
```

Output: `build/Build/Products/Release/Online.app` and `build/Online.dmg`.

## Run

1. Build and run from Xcode, or open `Online.app`
2. Grant notification permission when prompted
3. Optional: Online → Settings to add custom hosts (e.g. work VPN endpoint) and enable launch at login

## Settings

- **Polling interval** — 2s, 5s, 10s, or 30s (doubles on battery, max 8s)
- **Custom hosts** — hostnames probed via HTTPS HEAD
- **Launch at login** — register with `SMAppService`

## Architecture

```
ProbeEngine (tick loop)
  → PathProbe, GatewayProbe, DNSProbe, HTTPProbe, CustomHostProbe
  → ConnectivityStateMachine (debounce + wake grace)
  → AlertService + OutageLog + MenuBarExtra UI
```

## Distribution

v0.1 is intended for local builds and [GitHub Releases](https://github.com/Jubblin/online/releases).

### CI

Every push to `main` and every pull request runs:

- **Test** — `xcodebuild test` on `macos-15` (unit tests)
- **Build** — Release `Online.app` artifact (7-day retention)

### Release

Push a version tag to publish a DMG:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The [Release workflow](.github/workflows/release.yml) builds `Online.dmg` and attaches it to a GitHub Release. Tags matching `v*` trigger the workflow; tags with a hyphen (e.g. `v0.2.0-beta.1`) are marked pre-release.

### Dependency updates

[Renovate](https://github.com/apps/renovate) is configured via [`renovate.json`](renovate.json) to keep GitHub Actions (and Swift packages when added) up to date. Install the [Renovate GitHub App](https://github.com/apps/renovate) on this repository to enable it.

### Local signing

Sign the app with your Developer ID before distributing outside your machine:

```bash
codesign --force --deep --sign "Developer ID Application: Your Name" build/Build/Products/Release/Online.app
```

## License

MIT
