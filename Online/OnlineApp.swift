import SwiftUI

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard UITestConfiguration.shouldUseRegularActivationPolicy else { return }
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard UITestConfiguration.isActive else { return }
        Task { @MainActor in
            UITestConfiguration.presentInitialWindowsIfNeeded()
        }
    }
}

@main
struct OnlineApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var coordinator: AppCoordinator = {
        let coordinator = AppCoordinator()
        if !UITestConfiguration.isActive, !UITestConfiguration.isXCTestProcess {
            coordinator.start()
        }
        return coordinator
    }()

    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { settings.showInMenuBar },
            set: { newValue in
                if settings.showInMenuBar != newValue {
                    settings.showInMenuBar = newValue
                }
            }
        )
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInserted) {
            MenuBarView()
                .environmentObject(coordinator)
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        } label: {
            Image(systemName: coordinator.status.state.menuBarSymbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(coordinator.iconColor)
                .opacity(coordinator.menuBarOpacity)
                .accessibilityLabel(coordinator.status.state.displayName)
        }
        .menuBarExtraStyle(.window)

        Window("Outage Log", id: "outage-log") {
            OutageLogView()
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        }
        .defaultSize(width: 800, height: 440)

        Settings {
            SettingsView()
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        }
        .defaultSize(width: 480, height: 560)
    }
}
