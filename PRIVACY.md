# Privacy Policy — Online

**Last updated:** 2026-08-04

Online is a native macOS menu bar utility. This policy describes what the app does with your data.

## Summary

Online does **not** collect, transmit, or sell personal data. Connectivity probes and outage history stay on your Mac. Optional update checks fetch a public signed appcast (and, for App Store builds, GitHub Releases metadata) over HTTPS.

## Data stored on your device

- **Settings** — poll interval, custom hosts, appearance, menu bar preferences, and whether automatic update checks are enabled (UserDefaults).
- **Outage log** — JSON file at `~/Library/Application Support/Online/outages.json` with timestamps, failure reasons, and probe summaries.

You can view, copy, or delete outage records from the app.

## Network activity

Online performs connectivity checks (path monitor, gateway, DNS, HTTP HEAD, optional custom hosts) to determine whether your internet connection is working. Those requests go to your network and configured endpoints only.

When automatic updates are enabled (default), or when you choose **Check for Updates…**:

- **GitHub / Developer ID builds** use [Sparkle](https://sparkle-project.org/) to fetch a public signed appcast hosted on this repository’s Releases, then download and install the matching update archive when you approve. By default only the official channel is considered; you can opt in to the prerelease channel in Settings → Help.
- **Mac App Store builds** do not install updates in-app (the store owns updates). They may still check the public [GitHub Releases](https://github.com/Jubblin/online/releases) API to notify you that a newer build exists.

Those requests send a standard User-Agent including the installed app version. No account, analytics, or personal profile data is sent. You can turn automatic checks off in Settings → Help.

## Notifications

If you grant permission, macOS delivers local alerts when Online detects a confirmed outage or recovery, and optionally when a newer official release is available. Notification content is generated on device.

## Analytics and tracking

Online includes no analytics SDKs, advertising, or third-party tracking.

## Contact

Questions or concerns: [open a GitHub issue](https://github.com/Jubblin/online/issues/new/choose).
