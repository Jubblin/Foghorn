# Privacy Policy — Online

**Last updated:** 2026-08-01

Online is a native macOS menu bar utility. This policy describes what the app does with your data.

## Summary

Online does **not** collect, transmit, or sell personal data. Connectivity probes and outage history stay on your Mac. Optional update checks ask GitHub for public release metadata only.

## Data stored on your device

- **Settings** — poll interval, custom hosts, appearance, menu bar preferences, and whether automatic update checks are enabled (UserDefaults).
- **Outage log** — JSON file at `~/Library/Application Support/Online/outages.json` with timestamps, failure reasons, and probe summaries.

You can view, copy, or delete outage records from the app.

## Network activity

Online performs connectivity checks (path monitor, gateway, DNS, HTTP HEAD, optional custom hosts) to determine whether your internet connection is working. Those requests go to your network and configured endpoints only.

When automatic updates are enabled (default), or when you choose **Check for Updates…**, Online requests the public [GitHub Releases](https://github.com/Jubblin/online/releases) API for this repository to learn whether a newer version exists. By default only official (non-prerelease) tags are considered; you can opt in to pre-releases in Settings → Help. That request sends a standard User-Agent including the installed app version. No account, analytics, or personal profile data is sent. You can turn automatic checks off in Settings → Help.

## Notifications

If you grant permission, macOS delivers local alerts when Online detects a confirmed outage or recovery, and optionally when a newer official release is available. Notification content is generated on device.

## Analytics and tracking

Online includes no analytics SDKs, advertising, or third-party tracking.

## Contact

Questions or concerns: [open a GitHub issue](https://github.com/Jubblin/online/issues/new/choose).
