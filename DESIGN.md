# Design System - Online

## Product Context

- **What this is:** Online is a native macOS menu bar utility that monitors real internet connectivity with layered probes. It stays quiet when the network is healthy and alerts only when a confirmed failure survives debounce checks.
- **Who it's for:** Remote workers, developers, and Mac users who need to know whether the problem is their router, DNS, ISP, captive portal, or custom endpoint.
- **Space/industry:** macOS menu bar utilities, lightweight network monitors, and local diagnostic tools. Relevant peers include iStat Menus, Little Snitch Mini, Pulse, Me Or Them, Yifi, and native macOS status utilities.
- **Project type:** Native macOS SwiftUI app with a menu bar popover, Settings window, and outage log table.

## Aesthetic Direction

- **Direction:** Industrial minimal field instrument.
- **Decoration level:** Intentional. Use subtle graphite/glass surfaces, thin dividers, small signal marks, and restrained glow only for live status.
- **Mood:** Online should feel like a quiet sentinel: invisible until the network lies. The product should feel calm, precise, and hard to fool, not like a dashboard trying to entertain the user.
- **Reference sites:** Research included iStat Menus, Little Snitch Mini, Pulse, Me Or Them, Yifi, and macOS `MenuBarExtra` design patterns.

## Typography

- **Display/Hero:** Satoshi or Sohne when licensed. Use Instrument Sans as the open-source default.
- **Body:** Instrument Sans, because it is clean, readable, and less generic than system UI defaults while still feeling native enough for a Mac utility.
- **UI/Labels:** Instrument Sans Medium/Semibold for controls, labels, and menu actions.
- **Data/Tables:** JetBrains Mono, because probe summaries and outage rows need a compact tabular feel that reads like evidence.
- **Code:** JetBrains Mono.
- **Loading:** Prefer bundling fonts for releases. During prototypes or docs previews, Google Fonts is acceptable for Instrument Sans and JetBrains Mono.
- **Scale:**
  - 2xs: 11px, probe metadata and dense table hints
  - xs: 12px, table rows and timestamp labels
  - sm: 13px, menu actions
  - md: 15px, body text
  - lg: 18px, popover status line
  - xl: 24px, section titles
  - 2xl: 36px, marketing or docs headings

## Color

- **Approach:** Restrained. Neutrals carry the interface; color appears only when it communicates network truth.
- **Primary:** `#050708` Abyss, the dark base for the sentinel identity.
- **Secondary:** `#0E1415` Graphite, the main surface color for popovers, cards, and dark-mode windows.
- **Surface:** `#1C2828` Signal Glass, used for elevated panels and subtle status areas.
- **Text:** `#D7E2DA` Fog Text, main text on dark surfaces.
- **Muted:** `#7F918A` Muted Lichen, secondary text and timestamps.
- **Semantic:**
  - Success: `#62D26F` Truth Green
  - Warning: `#F2C94C` Warning Amber
  - Error: `#FF4D3D` Outage Red
  - Info: `#5CB7E8` Probe Blue
- **Dark mode:** Native default. Keep surfaces low-luminance and avoid pure black except for page or app chrome.
- **Light mode:** Use cool off-white backgrounds (`#EEF3EF`), deep text (`#17201E`), and keep semantic colors slightly darker if contrast needs it.

## Spacing

- **Base unit:** 4px.
- **Density:** Compact. This is a menu bar app; the UI should feel one-click and information-dense without becoming cramped.
- **Scale:** 2xs 2px, xs 4px, sm 8px, md 16px, lg 24px, xl 32px, 2xl 48px, 3xl 64px.

## Layout

- **Approach:** Grid-disciplined for app surfaces, black-box-recorder style for outage history.
- **Popover:** Lead with a sentence-level status, then show probe rows. Avoid making the popover a mini analytics dashboard.
- **Settings:** Group by user promises:
  - When to interrupt me
  - What Online checks
  - What Online remembers
- **Outage Log:** Treat as evidence. Rows should emphasize started, ended, duration, failure layer, and probe summary.
- **Grid:** Single-column in the popover, two-column only in wider Settings windows, table-first for logs.
- **Max content width:** Popover around 280-360px. Settings around 460-560px. Log window around 800px minimum.
- **Border radius:** sm 4px, md 8px, lg 12px, xl 18px, full 999px. Use larger radii only for popover containers and status pills.

## Motion

- **Approach:** Minimal-functional.
- **Easing:** Enter ease-out, exit ease-in, status movement ease-in-out.
- **Duration:** Micro 50-100ms, short 150-250ms, medium 250-400ms.
- **Rules:** Animate only state comprehension: checking pulse, recovery transition, and popover/window appearance. Do not animate red for decoration. Red means evidence, not personality.

## Component Guidance

- **Menu bar icon:** Dim when healthy, high contrast when degraded or outage. Prefer a sentinel-dot feel over a branded badge.
- **Status sentence:** The first visible text should answer the user's question plainly, for example "Internet is telling the truth" or "DNS is failing."
- **Probe rows:** Use monospace labels and concise details: `path:ok gateway:ok dns:fail http:ok`.
- **Outage records:** Show ended time and duration as first-class fields. An ongoing record should be visually distinct but not alarming unless the outage is active.
- **Color usage:** Green, amber, red, and blue are semantic. Do not use them as decoration.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-03 | Initial design system created | Created by `/design-consultation` for a native macOS menu bar utility whose memorable idea is "a quiet sentinel: invisible until the network lies." |
| 2026-07-03 | Keep category-safe native restraint | Users expect a Mac utility to be quiet, compact, and reliable. |
| 2026-07-03 | Take risk on field-instrument identity | The product is more memorable when it feels like evidence capture, not another generic network dashboard. |
