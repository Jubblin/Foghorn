# App Review notes (Mac App Store)

Use this text in **App Review Information → Notes** when submitting Online.

---

Online is a local network connectivity monitor for macOS. It runs in the menu bar and checks whether your internet connection is working.

**What the app does**
- Monitors network path, default gateway, DNS, and HTTP reachability on a timer
- Shows status in the menu bar and optional local notifications on confirmed outages
- Stores outage history locally at `~/Library/Application Support/Online/outages.json`

**What the app does NOT do**
- No accounts, login, or cloud sync
- No analytics, advertising, or third-party SDKs
- No data transmitted to the developer

**Permissions**
- **Notifications** — optional; requested on first confirmed outage (not at launch)
- **Network client** — required for connectivity probes (HTTP HEAD, DNS, TCP to gateway)
- **App Sandbox** — enabled

**How to test**
1. Launch Online — menu bar icon appears (dim green when healthy)
2. Open Settings (app menu → Settings or popover → Settings)
3. Disconnect Wi‑Fi or Ethernet for ~20 seconds — status should change to offline; notification may appear if permission granted
4. Reconnect — status returns to healthy; recovery notification if permission granted

**Support URL:** https://github.com/Jubblin/online/issues  
**Privacy Policy URL:** https://jubblin.github.io/online/privacy.html

**Export compliance:** App uses only standard HTTPS/TLS provided by macOS; `ITSAppUsesNonExemptEncryption` = NO.
