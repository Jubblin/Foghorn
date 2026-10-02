# Pre-release checklist

Run on a **Release** build before tagging a GitHub release or uploading to TestFlight.

## Automated (CI)

- [ ] SwiftLint + ShellCheck pass
- [ ] Unit tests pass (`FoghornTests`)
- [ ] UI smoke tests pass (`FoghornUITests`)

## Settings & windows

- [ ] Settings opens with four tabs (Interrupt, Checks, Remembers, Help)
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

- [ ] **GitHub DMGs** — arm64 and amd64 open without Gatekeeper block (`spctl -a -vv -t install Foghorn-<version>-arm64.dmg`)
- [ ] **TestFlight** — install succeeds; same version as GitHub tag
- [ ] Release notes match CHANGELOG section for the version

## App Store metadata (first submission)

- [ ] Privacy policy URL live (HTTPS)
- [ ] Screenshots 1280×800 captured
- [ ] App Privacy questionnaire completed in App Store Connect
- [ ] Reviewer notes describe network probing and no data collection

## FoghorniOS (manual, real device required — see #121, #137)

CI builds `FoghorniOS` and runs `FoghorniOSTests` (shared logic: state machine,
probes, outage log, background-monitoring lifecycle) on the simulator — see #137.
There is still no UI test target, and the simulator does not reliably reproduce the
Local Network permission prompt or background execution timing, so these need a real
iPhone:

- [ ] Fresh install — Local Network permission prompt appears the first time the gateway
      probe runs (not at launch); denying it does not crash the app or freeze the status
      (`GatewayProbe` falls back to `NWPath.gateways` — see #120)
- [ ] Background link-loss — disable Wi‑Fi/cellular while backgrounded; a notification
      fires promptly via the `NWPathMonitor` push path (`BackgroundMonitor`, #115)
- [ ] Background deep-probe — leave the app backgrounded for the `BGAppRefreshTask`
      window (no fixed interval — best effort); confirm a captive-portal or DNS-only
      outage is still detected and notified while backgrounded
- [ ] Force-quit recovery — force-quit the app while monitoring, then relaunch; the
      "Monitoring paused — reopen Foghorn to resume" banner appears (not silent/stale
      status)
- [ ] iPhone app icon renders correctly on the home screen and in Settings (#119)

