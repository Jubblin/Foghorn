import SwiftUI

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
struct OnlineApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var coordinator: AppCoordinator = {
        let coordinator = AppCoordinator()
        coordinator.start()
        return coordinator
    }()

    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { settings.showInMenuBar },
            set: { newValue in
                // Guard equal writes: SwiftUI re-asserts this binding on every
                // app-graph update. Without this check the @Published setter
                // fires objectWillChange on identical values, which rebuilds the
                // scene tree and loops forever, pinning the main thread.
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
        } label: {
            Image(systemName: coordinator.status.state.menuBarSymbol)
                .symbolRenderingMode(.palette)
                .foregroundStyle(coordinator.iconColor)
                .opacity(coordinator.menuBarOpacity)
                .accessibilityLabel(coordinator.status.state.displayName)
        }
        .menuBarExtraStyle(.menu)

        Window("Outage Log", id: "outage-log") {
            OutageLogView()
        }
        .defaultSize(width: 800, height: 440)

        Settings {
            SettingsView()
        }
    }
}
