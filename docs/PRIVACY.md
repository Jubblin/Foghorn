# Privacy Policy — Foghorn

**Last updated:** 2026-09-02

Foghorn is a native connectivity monitor for macOS and iOS. This policy describes what the app does with your data on either platform.

## Summary

Foghorn does **not** collect, transmit, or sell personal data. Connectivity probes and outage history stay on your device. Optional update checks (macOS only — see Network activity below) fetch a public signed appcast or GitHub Releases metadata over HTTPS.

## Data stored on your device

- **Settings** — poll interval, custom hosts, appearance, menu bar preferences, and whether automatic update checks are enabled (UserDefaults). On iOS, the equivalent app-level preferences are stored the same way; there is no menu bar.
- **Outage log** — JSON file at `Application Support/Foghorn/outages.json` inside the app's own sandboxed container, with timestamps, failure reasons, and probe summaries. The path is the same `applicationSupportDirectory` API on both macOS and iOS.

You can view and copy outage records in the app. On macOS you can also reveal `outages.json`
in Finder to delete it yourself; on iOS there is no Files access to the container, so use
the in-app outage log view. The app does not delete records for you on either platform.

## Network activity

Foghorn performs connectivity checks (path monitor, gateway, DNS, HTTP HEAD, optional custom hosts) to determine whether your internet connection is working. Those requests go to your network and configured endpoints only. On iOS, the gateway check may prompt for the Local Network permission the first time it runs a connectivity check against your router's address — used only for that check, never to scan or identify other devices on your network.

Automatic update checks apply to macOS only — iOS updates come from the App Store, and the app makes no update-check network calls on that platform. When automatic updates are enabled on macOS (default), or when you choose **Check for Updates…**:

- **GitHub / Developer ID builds** use [Sparkle](https://sparkle-project.org/) to fetch a public signed appcast hosted on this repository’s Releases, then download and install the matching update archive when you approve. By default only the official channel is considered; you can opt in to the prerelease channel in Settings → Remembers.
- **Mac App Store builds** do not install updates in-app (the store owns updates). They may still check the public [GitHub Releases](https://github.com/Jubblin/Foghorn/releases) API to notify you that a newer build exists.

Those requests send a standard User-Agent including the installed app version. No account, analytics, or personal profile data is sent. You can turn automatic checks off in Settings → Remembers (macOS).

## Notifications

If you grant permission, the app delivers local alerts when Foghorn detects a confirmed outage or recovery — on iOS, both while the app is open and, best-effort, while backgrounded (see the iOS section of `docs/APP_REVIEW_NOTES.md` for how background monitoring works). On macOS, a newer-release notice may also appear. Notification content is generated entirely on device.

## Analytics and tracking

Foghorn includes no analytics SDKs, advertising, or third-party tracking.

## Contact

Questions or concerns: [open a GitHub issue](https://github.com/Jubblin/Foghorn/issues/new/choose).
