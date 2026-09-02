import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Launch-argument harness for `FoghornUITests`. Active only when `-ui_testing` is passed.
enum UITestConfiguration {
    static let uiTestingFlag = "-ui_testing"
    static let openSettingsFlag = "-ui_testing_open_settings"
    static let openOutageLogFlag = "-ui_testing_open_outage_log"
    static let notificationStatusFlag = "-ui_testing_notifications"
    static let menuBarFlag = "-ui_testing_menu_bar"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingFlag)
    }

    /// True when launched by `xcodebuild test` / XCTest (including pre-bootstrap).
    static var isXCTestProcess: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// True when this process must not touch the developer's real Foghorn state:
    /// UI-test launches and the unit-test host.
    static var usesScratchStorage: Bool {
        isActive || isXCTestProcess
    }

    /// Preferences for this process. Test runs get a scratch suite, wiped at launch,
    /// so a run neither inherits nor leaves behind real settings (#87).
    static let defaults: UserDefaults = {
        let suiteName = "com.online.menu.uitests"
        guard usesScratchStorage, let suite = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        suite.removePersistentDomain(forName: suiteName)
        return suite
    }()

    /// Scratch directory for the outage log during test runs; `nil` in normal use,
    /// where the log belongs in Application Support.
    static let stateDirectory: URL? = {
        guard usesScratchStorage else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "FoghornTestState-\(ProcessInfo.processInfo.processIdentifier)",
                isDirectory: true
            )
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    static var shouldUseRegularActivationPolicy: Bool {
        isActive || isXCTestProcess
    }

    /// Runs the real launch path (coordinator + status item + SwiftUI `Settings`
    /// scene) so tests can exercise the popover routes rather than a stand-in window.
    static var shouldInstallMenuBar: Bool {
        ProcessInfo.processInfo.arguments.contains(menuBarFlag)
    }

    static var shouldOpenSettings: Bool {
        ProcessInfo.processInfo.arguments.contains(openSettingsFlag)
    }

    static var shouldOpenOutageLog: Bool {
        ProcessInfo.processInfo.arguments.contains(openOutageLogFlag)
    }

    static var mockNotificationAuthorization: NotificationAuthorizationDisplay? {
        guard isActive,
              let index = ProcessInfo.processInfo.arguments.firstIndex(of: notificationStatusFlag),
              index + 1 < ProcessInfo.processInfo.arguments.count else {
            return nil
        }

        switch ProcessInfo.processInfo.arguments[index + 1].lowercased() {
        case "authorized", "granted":
            return .granted
        case "denied":
            return .denied
        case "notdetermined", "not_determined":
            return .notDetermined
        default:
            return nil
        }
    }

    @MainActor
    static func bootstrap() {
        guard isActive, let mock = mockNotificationAuthorization else { return }
        AlertService.shared.applyUITestAuthorization(mock)
    }

    @MainActor
    static func presentInitialWindowsIfNeeded() {
        guard isActive else { return }

        bootstrap()

        DispatchQueue.main.async {
            if shouldOpenSettings {
                presentSettingsWindow()
            }
            if shouldOpenOutageLog {
                presentOutageLogWindow()
            }
            #if canImport(AppKit)
            NSApp.activate(ignoringOtherApps: true)
            #endif
        }
    }

    @MainActor
    private static func presentSettingsWindow() {
        #if canImport(AppKit)
        let settings = AppSettings.shared
        let hostingController = NSHostingController(
            rootView: SettingsView()
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 480, height: 560))
        window.center()
        window.makeKeyAndOrderFront(nil)
        #else
        // iOS has no equivalent UI-test window presentation path.
        #endif
    }

    @MainActor
    private static func presentOutageLogWindow() {
        #if canImport(AppKit)
        let hostingController = NSHostingController(rootView: OutageLogView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Outage Log"
        window.setContentSize(NSSize(width: 800, height: 440))
        window.center()
        window.makeKeyAndOrderFront(nil)
        #else
        // iOS has no equivalent UI-test window presentation path.
        #endif
    }
}
