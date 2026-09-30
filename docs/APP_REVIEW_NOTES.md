# App Review notes (Mac App Store)

Use this text in **App Review Information → Notes** when submitting Foghorn.

---

Foghorn is a local network connectivity monitor for macOS. It runs in the menu bar and checks whether your internet connection is working.

**What the app does**
- Monitors network path, default gateway, DNS, and HTTP reachability on a timer
- Shows status in the menu bar and optional local notifications on confirmed outages
- Stores outage history locally at `~/Library/Application Support/Foghorn/outages.json`

**What the app does NOT do**
- No accounts, login, or cloud sync
- No analytics, advertising, or third-party SDKs
- No data transmitted to the developer

**Permissions**
- **Notifications** — optional; requested on first confirmed outage (not at launch)
- **Network client** — required for connectivity probes (HTTP HEAD, DNS, TCP to gateway)
- **App Sandbox** — enabled

**How to test**
1. Launch Foghorn — menu bar icon appears (dim green when healthy)
2. Open Settings (app menu → Settings or popover → Settings)
3. Disconnect Wi‑Fi or Ethernet for ~20 seconds — status should change to offline; notification may appear if permission granted
4. Reconnect — status returns to healthy; recovery notification if permission granted

**Support URL:** https://github.com/Jubblin/Foghorn/issues  
**Privacy Policy URL:** https://jubblin.github.io/Foghorn/privacy.html

**Export compliance:** App uses only standard HTTPS/TLS provided by macOS; `ITSAppUsesNonExemptEncryption` = NO.

## iOS (FoghorniOS)

The iPhone build shares the same probing logic and data handling as the Mac app above (no accounts, no analytics, no data transmitted to the developer). Differences:

**Permissions**
- **Local Network** — requested the first time the gateway probe runs; used only to check whether the router at the local gateway address is reachable, to tell a router problem apart from an upstream/ISP outage. The app does not scan the network or identify other devices (see `NSLocalNetworkUsageDescription` in `Foghorn/iOS/Info.plist`).
- **Notifications** — same behavior as macOS: requested on first confirmed outage, not at launch.
- **Background App Refresh** — used via `BGAppRefreshTask` to run periodic connectivity checks while backgrounded; interval is best-effort and scheduled by iOS, not a fixed cadence.

**Background behavior to note for review**
- Link-level changes (Wi-Fi/cellular drop or restore) can trigger a notification immediately via `NWPathMonitor`'s push callback, even in the background.
- Deeper checks (gateway/DNS/HTTP) run opportunistically via `BGAppRefreshTask` — there is no guaranteed floor on interval, per Apple's background execution model.
- If the app is force-quit by the user, monitoring cannot continue (iOS provides no way around this). On next launch the app shows "Monitoring paused — reopen Foghorn to resume" rather than stale or silent status.

