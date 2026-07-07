# UI testing (OnlineUITests)

XCUITest smoke tests for Settings and the outage log window.

## Run locally

```bash
xcodebuild test \
  -project Online.xcodeproj \
  -scheme Online \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:OnlineUITests \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=NO
```

## Launch arguments (set by tests)

| Argument | Purpose |
|----------|---------|
| `-ui_testing` | Disables probe engine; enables mock notification state |
| `-ui_testing_open_settings` | Opens Settings on launch |
| `-ui_testing_open_outage_log` | Opens outage log window on launch |
| `-ui_testing_notifications denied\|notDetermined\|authorized` | Mocks notification permission |

## Known limitations

- **Menu bar (LSUIElement) apps** can hang or fail XCTest bootstrap on some macOS versions. The app switches to `.regular` activation policy when `XCTestConfigurationFilePath` is present.
- **Menu bar popover** is not automated — tests open Settings/outage log directly via `UITestConfiguration`.
- **Notification permission** dialogs are not automated; permission state is mocked.
- Grant **Accessibility** to Xcode / Terminal in System Settings if tests fail to find controls.

CI runs UI tests in a separate job with `continue-on-error: true` until bootstrap is stable on `macos-26` runners.
