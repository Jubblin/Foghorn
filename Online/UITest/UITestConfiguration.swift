import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Launch-argument harness for `OnlineUITests`. Active only when `-ui_testing` is passed.
enum UITestConfiguration {
    static let uiTestingFlag = "-ui_testing"
    static let openSettingsFlag = "-ui_testing_open_settings"
    static let openOutageLogFlag = "-ui_testing_open_outage_log"
    static let notificationStatusFlag = "-ui_testing_notifications"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingFlag)
    }

    /// True when launched by `xcodebuild test` / XCTest (including pre-bootstrap).
    static var isXCTestProcess: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var shouldUseRegularActivationPolicy: Bool {
        isActive || isXCTestProcess
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
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private static func presentSettingsWindow() {
        let settings = AppSettings.shared
        let hostingController = NSHostingController(
            rootView: SettingsView()
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 480, height: 720))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private static func presentOutageLogWindow() {
        let hostingController = NSHostingController(rootView: OutageLogView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Outage Log"
        window.setContentSize(NSSize(width: 800, height: 440))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
