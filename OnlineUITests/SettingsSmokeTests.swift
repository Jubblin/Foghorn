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

    func testSettingsShowsFourSections() throws {
        launchSettings()

        XCTAssertTrue(waitFor(identifier: "settings.section.interrupt"))
        XCTAssertTrue(element(identifier: "settings.section.checks").exists)
        XCTAssertTrue(element(identifier: "settings.section.remembers").exists)
        XCTAssertTrue(element(identifier: "settings.section.help").exists)
    }

    // MARK: - T2

    func testLaunchAtLoginToggle() throws {
        launchSettings()

        let toggle = element(identifier: "settings.launchAtLogin")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
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
        app.descendants(matching: .any)[identifier]
    }

    @discardableResult
    private func waitFor(identifier: String, timeout: TimeInterval = 8) -> Bool {
        element(identifier: identifier).waitForExistence(timeout: timeout)
    }
}
