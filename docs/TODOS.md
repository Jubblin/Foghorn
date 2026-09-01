# Foghorn — Backlog

## P1 — Important

_No open P1 items._

## P2 — Polish

- [ ] Bundle Instrument Sans + JetBrains Mono per DESIGN.md (deferred from /design-review 2026-07-03, FINDING-005)
- [ ] ~~Remove "View outage log…" / "Show in Finder" dropdown entries (SettingsView.swift:385,390)~~ — superseded by [#76](https://github.com/Jubblin/Foghorn/issues/76) on 2026-09-01: DESIGN.md:149-150 specs both as the canonical Settings actions, so the duplicate popover rows go instead
- [ ] Remove "Check for Updates…" from the menu bar popover (MenuBarView.swift:98) — split out of [#76](https://github.com/Jubblin/Foghorn/issues/76) on 2026-09-01; held back because the app runs `.accessory` (no app menu bar), so Settings (SettingsView.swift:459) becomes the only route. Confirm AppNavigation.openSettings is reliable first (see #66, #70)
- [ ] Update all docs (README, CONTRIBUTING, DESIGN, PRIVACY, docs/*) to match current feature set — idea logged 2026-08-29

## Ideas — Unscoped

- [ ] Automated testing of all commands as part of the build pipeline (logged 2026-08-29)

## Completed

- [x] Settings density & dedup (2026-07-06) — Enable alerts, inline Help links, four compact sections, no default scroll
- [x] Settings redesign per DESIGN.md (2026-07-04) — DesignPalette section cards, Help & privacy, notification status
- [x] Dark popover surface (2026-07-03) — Signal Glass/Graphite field-instrument popover from `/design-review`
- [x] Menu bar visibility toggle (2026-07-02) — `showInMenuBar` in Settings; probes + notifications continue when hidden
- [x] Outage log viewer (2026-07-02) — sortable table window, copy JSON, reveal in Finder
- [x] Traffic-light menu bar icons (2026-07-01) — green/yellow/red/gray `circle.fill` in menu bar
