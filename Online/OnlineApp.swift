import SwiftUI

@main
struct OnlineApp: App {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var coordinator: AppCoordinator = {
        let coordinator = AppCoordinator()
        coordinator.start()
        return coordinator
    }()

    var body: some Scene {
        MenuBarExtra(isInserted: $settings.showInMenuBar) {
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
