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

### 3. Traffic-light menu bar icons
Replace current SF Symbol status icons with traffic-light style indicators.

- [ ] **Green** — healthy / online
- [ ] **Yellow** — degraded / partial failure
- [ ] **Red** — outage
- [ ] **Gray** (optional) — recovering or unknown
- [ ] Update `ConnectivityState.menuBarSymbol` (or custom `Image` assets) in `MenuBarView` and `OnlineApp` menu bar label
- [ ] Match alert-first UX: subtle when green, obvious when red/yellow

## Completed

<!-- Move items here with date when done, e.g. - [x] Feature name (2026-07-08) -->
