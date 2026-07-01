# Online — Backlog

## P1 — Important

### 1. Menu bar visibility toggle
Allow the user to show or hide the menu bar icon without quitting the app.

- [ ] Add `showInMenuBar` (or similar) to `AppSettings` with UserDefaults persistence
- [ ] Settings UI toggle: "Show in menu bar"
- [ ] When disabled: stop showing `MenuBarExtra` (or hide via `NSStatusItem.isVisible` / conditional scene)
- [ ] Probes and alerts keep running in the background when hidden
- [ ] Document behavior in README (hidden ≠ quit)

### 2. Outage log viewer (JSON → table)
In-app viewer for `~/Library/Application Support/Online/outages.json`.

- [ ] New view (Settings tab or menu dropdown): "Outage log"
- [ ] Load records from `OutageLog` / on-disk JSON
- [ ] Render as sortable table: start time, end time, duration, state, failure reason, probe snapshot summary
- [ ] Empty state when no outages recorded
- [ ] Optional: export or copy raw JSON for debugging

## P2 — Polish

## Completed

- [x] Traffic-light menu bar icons (2026-07-01) — green/yellow/red/gray `circle.fill` in menu bar
