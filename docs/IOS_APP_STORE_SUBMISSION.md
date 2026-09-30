# iOS App Store submission checklist (FoghorniOS)

`FoghorniOS` uses bundle ID `com.online.menu.ios`, distinct from the macOS app's
`com.online.menu` — this is a **separate App Store listing**, not a universal purchase.
None of the steps below can be automated from CI or done without an Apple Developer
account; they're recorded here so the work is scoped and nothing gets missed on first
submission.

## 1. App Store Connect record

- [ ] Create a new app in App Store Connect under the same team as the macOS app
- [ ] Bundle ID: `com.online.menu.ios` (must be registered in the Apple Developer portal
      first if it isn't already — check before creating the ASC record)
- [ ] SKU and app name: confirm whether this ships as "Foghorn" (same name, different
      platform, common for iOS companions) or a distinguishing name — App Store search
      will otherwise show two "Foghorn" listings with no visual way to tell them apart
      until you tap in

## 2. Screenshots

- [ ] Capture iPhone-size screenshots of `IOSHomeView` in both light and dark mode,
      healthy and outage states — the existing `docs/screenshots/*.png` are macOS menu-bar
      popovers at 1280×800 and do not carry over
- [ ] Required sizes depend on which device classes you support (`TARGETED_DEVICE_FAMILY = 1`
      is iPhone-only currently) — check current App Store Connect requirements at
      submission time, sizes have changed across iOS/Xcode versions
- [ ] Recommend deferring capture until #123 (iOS v1 feature scope) is settled, since the
      screenshots should reflect the actual shipped UI, not an interim one

## 3. App Privacy questionnaire

Should mirror the answers already given for the macOS app (see `PRIVACY.md` /
`docs/APP_REVIEW_NOTES.md`, now updated with the iOS-specific sections):

- [ ] No data collected that is linked to the user's identity
- [ ] No tracking across apps/websites
- [ ] Local Network permission usage declared, scoped to "App functionality" (router
      reachability check), not analytics/advertising

## 4. Reviewer notes

- [ ] `docs/APP_REVIEW_NOTES.md` now has an iOS section (added alongside this checklist)
      covering the Local Network permission and background monitoring model — paste the
      relevant section into App Review Information → Notes when submitting, same as the
      macOS process already documented there

## 5. Privacy Policy URL

- [ ] `PRIVACY.md` / `docs/privacy.html` now describe both platforms in one document —
      confirm the existing URL (https://jubblin.github.io/Foghorn/privacy.html) is
      acceptable to reuse for the iOS listing, or whether App Store Connect wants a
      platform-specific one (it does not, per Apple's current guidelines, but re-check
      at submission time since policy requirements do shift)

## 6. Prerequisites from other issues

This submission cannot happen until:

- iOS distribution certificate + provisioning profile exist (#122 — release pipeline)
- The app builds and archives cleanly for `Release` (depends on #119 icon fix landing)
- v1 feature scope is decided (#123) so screenshots and the listing description are final,
  not written against an interim UI
