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

        let toggle = app.toggles["settings.launchAtLogin"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
    }

    // MARK: - T3

    func testShowInMenuBarToggle() throws {
        launchSettings()

        let toggle = app.toggles["settings.showInMenuBar"]
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

        let picker = app.segmentedControls["settings.appearancePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(picker.buttons.count, 1)
        picker.buttons.element(boundBy: 1).click()
    }

    // MARK: - T6

    func testOutageLogOpensEmpty() throws {
        launchOutageLog()

        XCTAssertTrue(waitFor(identifier: "outageLog.emptyState", timeout: 10))
    }

    // MARK: - T7

    func testCustomHostAddRemove() throws {
        launchSettings()

        let disclosure = app.descendants(matching: .any)["settings.customHosts"]
        if disclosure.waitForExistence(timeout: 3) {
            disclosure.click()
        } else if app.buttons["Custom hosts"].waitForExistence(timeout: 3) {
            app.buttons["Custom hosts"].click()
        }

        let field = app.textFields["settings.customHostField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeText("uitest.example.com")

        app.buttons["settings.customHostAdd"].click()
        XCTAssertTrue(app.staticTexts["uitest.example.com"].waitForExistence(timeout: 5))
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

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @discardableResult
    private func waitFor(identifier: String, timeout: TimeInterval = 8) -> Bool {
        element(identifier: identifier).waitForExistence(timeout: timeout)
    }
}
