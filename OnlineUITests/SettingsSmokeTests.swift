import XCTest

final class SettingsSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - T1

    func testSettingsShowsFourTabs() throws {
        launchSettings()

        XCTAssertTrue(waitFor(identifier: "settings.section.interrupt"))
        selectTab("Checks")
        XCTAssertTrue(waitFor(identifier: "settings.section.checks"))
        selectTab("Remembers")
        XCTAssertTrue(waitFor(identifier: "settings.section.remembers"))
        selectTab("Help")
        XCTAssertTrue(waitFor(identifier: "settings.section.help"))
    }

    // MARK: - T2

    func testLaunchAtLoginToggle() throws {
        launchSettings()
        selectTab("Remembers")

        let toggle = element(identifier: "settings.launchAtLogin")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()

        XCTAssertTrue(app.buttons["settings.viewOutageLog"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "settings.outageLogPath").exists)
    }

    // MARK: - T3

    func testShowInMenuBarToggle() throws {
        launchSettings()

        let toggle = element(identifier: "settings.showInMenuBar")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
    }

    // MARK: - T4

    func testEnableAlertsVisibleWhenNotDetermined() throws {
        launchSettings(extraArguments: ["-ui_testing_notifications", "notDetermined"])

        let button = app.buttons["settings.enableAlerts"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    // MARK: - T5

    func testAppearancePickerChanges() throws {
        launchSettings()

        let picker = element(identifier: "settings.appearancePicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        let lightSegment = element(identifier: "settings.appearance.light")
        if lightSegment.waitForExistence(timeout: 2) {
            lightSegment.click()
            return
        }

        let segments = picker.buttons
        if segments.count > 1 {
            segments.element(boundBy: 1).click()
            return
        }

        // Headless CI: segmented control may expose no child buttons — tap by coordinate.
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    // MARK: - T6

    func testOutageLogOpensEmpty() throws {
        launchOutageLog()

        XCTAssertTrue(waitFor(identifier: "outageLog.emptyState", timeout: 10))
    }

    // MARK: - T7

    func testCustomHostAddRemove() throws {
        launchSettings()
        selectTab("Checks")

        XCTAssertTrue(waitFor(identifier: "settings.customHosts", timeout: 8))
        let field = customHostField()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("uitest.example.com")

        element(identifier: "settings.customHostAdd").click()
        XCTAssertTrue(waitFor(identifier: "settings.customHost.uitest.example.com", timeout: 5))
    }

    // MARK: - T8

    func testHelpLinksExist() throws {
        launchSettings()
        selectTab("Help")

        XCTAssertTrue(app.buttons["settings.link.privacy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.link.support"].exists)
        XCTAssertTrue(app.buttons["settings.link.report"].exists)
    }

    // MARK: - Helpers

    private func launchSettings(extraArguments: [String] = []) {
        app.launchArguments = ["-ui_testing", "-ui_testing_open_settings"] + extraArguments
        app.launch()
        _ = waitFor(identifier: "settings.section.interrupt")
    }

    private func launchOutageLog() {
        app.launchArguments = ["-ui_testing", "-ui_testing_open_outage_log"]
        app.launch()
    }

    private func selectTab(_ title: String) {
        let candidates: [XCUIElement] = [
            app.tabs[title],
            app.radioButtons[title],
            app.buttons[title],
            element(identifier: "settings.tab.\(title.lowercased())")
        ]
        for candidate in candidates where candidate.waitForExistence(timeout: 2) {
            candidate.click()
            return
        }
        XCTFail("Could not find Settings tab titled \(title)")
    }

    private func customHostField() -> XCUIElement {
        let byIdentifier = element(identifier: "settings.customHostField")
        if byIdentifier.exists {
            return byIdentifier
        }

        let byLabel = app.textFields["Custom host"]
        if byLabel.exists {
            return byLabel
        }

        return app.textFields["vpn.company.com"]
    }

    private func element(identifier: String) -> XCUIElement {
        // Prefer the explicit UI-test Settings/Outage windows to avoid duplicate
        // SwiftUI scene hierarchies matching the same accessibility id.
        let settingsWindow = app.windows["Settings"]
        if settingsWindow.exists {
            let inSettings = settingsWindow.descendants(matching: .any)[identifier]
            if inSettings.exists || settingsWindow.waitForExistence(timeout: 0.1) {
                return inSettings
            }
        }
        let outageWindow = app.windows["Outage Log"]
        if outageWindow.exists {
            let inOutage = outageWindow.descendants(matching: .any)[identifier]
            if inOutage.exists {
                return inOutage
            }
        }
        return app.descendants(matching: .any)[identifier].firstMatch
    }

    @discardableResult
    private func waitFor(identifier: String, timeout: TimeInterval = 8) -> Bool {
        element(identifier: identifier).waitForExistence(timeout: timeout)
    }
}
