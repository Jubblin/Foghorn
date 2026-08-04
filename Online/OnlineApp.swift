import SwiftUI

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    nonisolated func applicationWillFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            if UITestConfiguration.shouldUseRegularActivationPolicy {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        // AppKit invokes this on the main thread.
        MainActor.assumeIsolated {
            self.handleDidFinishLaunching()
        }
    }

    private func handleDidFinishLaunching() {
        // Explicit accessory policy. Relying on Info.plist LSUIElement alone has
        // caused Control Center to suppress status items on macOS 26/27 betas.
        if !UITestConfiguration.shouldUseRegularActivationPolicy {
            NSApp.setActivationPolicy(.accessory)
        }

        AppSettings.applyAppKitAppearance(AppSettings.shared.appearancePreference)

        if UITestConfiguration.isActive {
            UITestConfiguration.presentInitialWindowsIfNeeded()
            return
        }

        if !UITestConfiguration.isXCTestProcess {
            coordinator.start()
            StatusItemController.shared.install(coordinator: coordinator)
        }

        if ProcessInfo.processInfo.arguments.contains("-open-settings") {
            Task { @MainActor in
                AppSettings.shared.showInMenuBar = true
                try? await Task.sleep(nanoseconds: 400_000_000)
                AppNavigation.openSettings()
            }
        }
    }
}

@main
struct OnlineApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        Settings {
            if UITestConfiguration.isActive {
                // UI tests host Settings in an explicit NSWindow (UITestConfiguration).
                // Avoid a second SettingsView in the SwiftUI Settings scene or XCTest
                // sees duplicate accessibility identifiers.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            } else {
                SettingsView()
                    .environmentObject(appDelegate.coordinator)
                    .preferredColorScheme(settings.appearancePreference.colorScheme)
                    // Force SwiftUI to drop a cached Light/Dark override when returning to System.
                    .id(settings.appearancePreference)
                    .background(OutageLogWindowBridge())
            }
        }
        .defaultSize(width: 480, height: 420)
        .windowResizability(.contentSize)

        Window("Outage Log", id: "outage-log") {
            if UITestConfiguration.isActive {
                // Same rationale as Settings — outage log is opened via UITestConfiguration.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            } else {
            OutageLogView()
                .preferredColorScheme(settings.appearancePreference.colorScheme)
                .id(settings.appearancePreference)
            }
        }
        .defaultSize(width: 800, height: 440)
    }
}

/// Forwards `AppNavigation.openOutageLog` into the SwiftUI `openWindow` environment.
private struct OutageLogWindowBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: AppNavigation.openOutageLogNotification)) { _ in
                openWindow(id: "outage-log")
            }
    }
}
