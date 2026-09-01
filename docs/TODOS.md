# Foghorn — Backlog

## P1 — Important

_No open P1 items._

## P2 — Polish

- [ ] Bundle Instrument Sans + JetBrains Mono per DESIGN.md (deferred from /design-review 2026-07-03, FINDING-005)
- [ ] Remove "View outage log…" / "Show in Finder" dropdown entries (SettingsView.swift:385,390) — idea logged 2026-08-29, needs a decision on the replacement entry point before removal
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
