# Pre-release checklist

Run on a **Release** build before tagging a GitHub release or uploading to TestFlight.

## Automated (CI)

- [ ] SwiftLint + ShellCheck pass
- [ ] Unit tests pass (`OnlineTests`)
- [ ] UI smoke tests pass (`OnlineUITests`)

## Settings & windows

- [ ] Settings opens with four sections (interrupt, checks, remembers, help)
- [ ] Launch at login toggle works (or shows a clear error)
- [ ] Enable alerts / notification status behaves correctly
- [ ] Outage log window opens; empty state when no records
- [ ] Custom host add/remove works

## Menu bar & popover (manual)

- [ ] **Healthy** — dim green icon (low opacity)
- [ ] **Degraded** — yellow icon
- [ ] **Offline** — red icon
- [ ] Popover shows correct probe rows for each state
- [ ] Settings and outage log open from popover actions

## Notifications (manual)

- [ ] Fresh install / denied permission — no prompt at launch
- [ ] Confirmed outage triggers notification permission request (if not determined)
- [ ] After granting permission, outage and recovery notifications fire
- [ ] **Enable alerts** in Settings works when permission not determined
- [ ] **Open Notification Settings** works when permission denied

## Connectivity (manual, sandbox build required for store)

- [ ] All probes pass on home Wi‑Fi with sandbox enabled
- [ ] Disconnect Wi‑Fi / gateway — outage recorded after eval window
- [ ] Reconnect — recovery notification and outage log end time

## Distribution artifacts

- [ ] **GitHub DMGs** — arm64 and amd64 open without Gatekeeper block (`spctl -a -vv -t install Online-<version>-arm64.dmg`)
- [ ] **TestFlight** — install succeeds; same version as GitHub tag
- [ ] Release notes match CHANGELOG section for the version

## App Store metadata (first submission)

- [ ] Privacy policy URL live (HTTPS)
- [ ] Screenshots 1280×800 captured
- [ ] App Privacy questionnaire completed in App Store Connect
- [ ] Reviewer notes describe network probing and no data collection
