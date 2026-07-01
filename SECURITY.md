# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report security issues privately using one of these channels:

1. **[GitHub Private Security Advisory](https://github.com/Jubblin/online/security/advisories/new)** (preferred)
2. Open a draft security advisory if you need coordinated disclosure

Include as much detail as possible:

- Description of the issue and potential impact
- Steps to reproduce
- Affected versions
- Any suggested fix or mitigation

You should receive an acknowledgment within **7 days**. We will work with you on
a fix and disclosure timeline before any public announcement.

## Security Model

Online is a local macOS menu bar utility. It:

- Performs outbound network probes (HTTP HEAD, DNS, TCP to gateway)
- Stores outage history locally at `~/Library/Application Support/Online/outages.json`
- Requests notification permission via `UserNotifications`
- Does **not** use the App Sandbox (see `Online.entitlements`)

The app does not collect analytics or transmit outage data off-device.

## Hardening Notes for Contributors

- Do not log or persist credentials, cookies, or response bodies from probes
- Validate and sanitize custom host entries before use in network requests
- Keep entitlements minimal when adding new capabilities
- Run `xcodebuild test` before submitting security-related changes
