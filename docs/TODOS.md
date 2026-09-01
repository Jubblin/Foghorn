# Foghorn — Backlog

Open work is tracked in [GitHub Issues](https://github.com/Jubblin/Foghorn/issues), not here.
This file keeps only the shipped history below.

Migrated 2026-09-01:

| Was | Now |
| --- | --- |
| Bundle Instrument Sans + JetBrains Mono per DESIGN.md | [#79](https://github.com/Jubblin/Foghorn/issues/79) |
| Remove "Check for Updates…" from the menu bar popover | [#80](https://github.com/Jubblin/Foghorn/issues/80) |
| Update all docs to match current feature set | [#81](https://github.com/Jubblin/Foghorn/issues/81) |
| Automated testing of all commands in the build pipeline | [#82](https://github.com/Jubblin/Foghorn/issues/82) |

The P2 entry proposing removal of the `SettingsView` outage-log actions was dropped
rather than migrated — [#76](https://github.com/Jubblin/Foghorn/issues/76) resolved it
in the opposite direction, and DESIGN.md:149-150 keeps those actions in Settings.

## Completed

- [x] Settings density & dedup (2026-07-06) — Enable alerts, inline Help links, four compact sections, no default scroll
- [x] Settings redesign per DESIGN.md (2026-07-04) — DesignPalette section cards, Help & privacy, notification status
- [x] Dark popover surface (2026-07-03) — Signal Glass/Graphite field-instrument popover from `/design-review`
- [x] Menu bar visibility toggle (2026-07-02) — `showInMenuBar` in Settings; probes + notifications continue when hidden
- [x] Outage log viewer (2026-07-02) — sortable table window, copy JSON, reveal in Finder
- [x] Traffic-light menu bar icons (2026-07-01) — green/yellow/red/gray `circle.fill` in menu bar
