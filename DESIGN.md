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
  - Help & privacy
  - About
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
- **Probe rows:** Use monospace labels and concise details: `PATH via en4/wired`, `GATEWAY 10.2.254.254`, `DNS ok`. Prefer interface/router evidence over bare `ok` when the probe provides it.
- **Outage records:** Show ended time and duration as first-class fields. An ongoing record should be visually distinct but not alarming unless the outage is active.
- **Color usage:** Green, amber, red, and blue are semantic. Do not use them as decoration.

## Settings Screen

The Settings window is a **configuration panel for a field instrument**, not a preferences junk drawer. It should feel as calm and precise as the popover: readable at a glance, dense but not cramped, and honest about what Online does with permissions and data.

### Window chrome

- **Size:** 480×560pt fixed (within the 460–560pt width range).
- **Background:** `graphite` from `DesignPalette` (not system default window gray).
- **Scroll:** Vertical scroll when content exceeds height; no horizontal scroll.
- **Title:** "Settings" (system window title). No marketing hero inside the window.

### Section structure

Use five promise-based sections in this order:

| Section | User promise | Controls |
|---------|--------------|----------|
| **When to interrupt me** | I control visibility and alerts | Menu bar toggle, appearance segmented control, notification permission status |
| **What Online checks** | I control probe cadence and targets | Base interval picker, custom hosts list + add field |
| **What Online remembers** | I control persistence and history | Launch at login, View outage log, log file path |
| **Help & privacy** | I can get help and understand data use | Privacy Policy, Support, Report an issue; version/build; optional GitHub Releases update check |
| **About** | I know what this app is | (Merged into Help & privacy in v1) version, build date, update controls |

Do not add sections for features that do not exist. Keep the sentinel posture: every row earns its place.

### Visual treatment

Apply the same palette as the menu bar popover (`DesignPalette.palette(colorScheme:)`), not vanilla `Form` system chrome alone.

- **Section container:** `signalGlass` background, 12px corner radius (`lg`), 16px (`md`) inner padding, 12px (`sm`) vertical gap between sections.
- **Section title:** 18px (`lg`) semibold, `fogText`. Use `Section` headers or explicit `Text` with `.font(.headline)` until Instrument Sans is bundled.
- **Control labels:** 15px (`md`) regular, `fogText`.
- **Helper / caption text:** 12px (`xs`), `mutedLichen`. Max two lines where possible; link to Support for longer explanations.
- **Dividers:** `palette.divider` (12% white/black opacity), not system `Divider` default.
- **Destructive / error text:** `outageRed` only for real errors (e.g. launch-at-login failure), never decoration.
- **Data paths and hostnames:** `JetBrains Mono` / `DesignTokens.dataFont`, `mutedLichen`, `.textSelection(.enabled)`.

Native macOS controls (Toggle, Picker, TextField, Button) stay native; only surfaces and typography follow the design system. This matches user expectations for a Mac utility while avoiding the "stock Settings clone" look.

### Section copy and behavior

**When to interrupt me**

- **Show in menu bar:** Existing toggle. Helper: "When hidden, Online keeps monitoring and sends notifications. Open Settings from the app menu to restore the icon."
- **Appearance:** Segmented control — Follow System / Light / Dark. Applies to popover and Settings immediately.
- **Notifications:** Show permission status as `LabeledContent`:
  - Granted → "Alerts enabled"
  - Not determined → "Not set up" + subtle prompt to grant on next outage (no nag modal in Settings)
  - Denied → "Denied" + button **Open Notification Settings** (deep link to System Settings → Notifications → Online)
- Do not use red for denied unless the user is in an active outage context.

**What Online checks**

- **Base interval:** Picker with 2s / 5s / 10s / 30s. Helper: "Interval doubles on battery power (max 8×)."
- **Custom hosts:** Empty state: "No custom hosts configured." (muted). List with swipe/delete. Add row: placeholder `vpn.company.com`, **Add** disabled when empty.
- Host rows: monospace hostname, no decorative icons.

**What Online remembers**

- **Launch at login:** Toggle with error caption on failure (red, one line).
- **View outage log…** — opens outage log window; does not navigate away from Settings.
- **Log path:** Monospace, muted, selectable. Treat as evidence location, not a secret.

**Help & privacy** (required for Mac App Store metadata alignment; includes About in v1)

- **Privacy Policy** — link opens default browser to hosted policy URL (GitHub Pages or project site). One line helper: "Online monitors connectivity locally — no personal data collected or transmitted."
- **Support** — link to support URL (GitHub issues or dedicated support page).
- **Report an issue** — link to GitHub issue chooser (can match Support URL if same destination).
- Use `Link` or `Button` that opens `NSWorkspace.shared.open`. No in-app WebView for policy pages in v1.
- **Version / Built:** `LabeledContent` with marketing version + build number and executable modification date (`AppInfo`).
- **Check for updates automatically** — Toggle (default on). Helper: looks up the latest official GitHub Release about once a day; ignores continuous `-build.N` tags.
- **Check for Updates…** — Manual check; opens arch-specific DMG (or Releases page) when an update is available. Menu bar popover exposes the same action.
- Update checks are not Sparkle in-app replacement until Developer ID signing is reliable; they notify and open the download URL.

**About**

- Content lives under Help & privacy in v1 (no separate section).

### App Store and review alignment

- Privacy Policy and Support URLs in **Help & privacy** must match App Store Connect entries exactly.
- Notification permission UX must be discoverable without a first-run blocking modal; Settings is the recovery path when users deny alerts.
- No analytics, ads, or account UI in Settings.
- Export compliance (`ITSAppUsesNonExemptEncryption` = NO) is Info.plist, not Settings UI.

### Motion

- Window appear: system default (no custom animation).
- Section expand/collapse: none in v1 (flat list of sections).
- Status changes (e.g. notification permission after returning from System Settings): refresh on `onAppear` / `scenePhase` active; no celebratory animation.

### Accessibility

- All controls must have accessibility labels matching visible text.
- Helper text associated with controls via `accessibilityHint` where SwiftUI allows.
- Color is never the only signal for notification status; always pair with text ("Denied", "Granted").

### Implementation notes

- Prefer a single `SettingsView` composed of section subviews (`SettingsInterruptSection`, etc.) for testability.
- `Help & privacy` link URLs should be constants (e.g. `AppLinks.privacyPolicy`, `AppLinks.support`) shared with App Store Connect copy.
- Until fonts are bundled (`TODOS.md`), use system fonts with `.headline` / `.caption` / `.monospaced` roles that map to the scale above.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-03 | Initial design system created | Created by `/design-consultation` for a native macOS menu bar utility whose memorable idea is "a quiet sentinel: invisible until the network lies." |
| 2026-07-03 | Keep category-safe native restraint | Users expect a Mac utility to be quiet, compact, and reliable. |
| 2026-07-03 | Take risk on field-instrument identity | The product is more memorable when it feels like evidence capture, not another generic network dashboard. |
| 2026-07-04 | Settings uses DesignPalette surfaces + five promise sections | Brings Settings in line with popover; adds Help & privacy and notification permission recovery for App Store readiness while keeping the quiet sentinel posture. |
| 2026-08-01 | GitHub Releases update checks under Help & privacy | Notify + open arch DMG until Developer ID/Sparkle; continuous `-build` tags ignored. |
| 2026-08-03 | PATH/GATEWAY rows show interface and router evidence | Users need to confirm which NIC the default path uses; OSLog records path flips. |
