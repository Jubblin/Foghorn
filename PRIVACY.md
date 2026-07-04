# Privacy Policy — Online

**Last updated:** 2026-07-04

Online is a native macOS menu bar utility. This policy describes what the app does with your data.

## Summary

Online does **not** collect, transmit, or sell personal data. Network probes run **locally on your Mac**. Outage history is stored **only on your device**.

## Data stored on your device

- **Settings** — poll interval, custom hosts, appearance, and menu bar preferences (UserDefaults).
- **Outage log** — JSON file at `~/Library/Application Support/Online/outages.json` with timestamps, failure reasons, and probe summaries.

You can view, copy, or delete outage records from the app.

## Network activity

Online performs connectivity checks (path monitor, gateway, DNS, HTTP HEAD, optional custom hosts) to determine whether your internet connection is working. These requests go to your network and configured endpoints only. Online does not phone home to a developer server.

## Notifications

If you grant permission, macOS delivers local alerts when Online detects a confirmed outage or recovery. Notification content is generated on device.

## Analytics and tracking

Online includes no analytics SDKs, advertising, or third-party tracking.

## Contact

Questions or concerns: [open a GitHub issue](https://github.com/Jubblin/online/issues/new/choose).
