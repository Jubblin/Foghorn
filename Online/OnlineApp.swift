import SwiftUI

@main
struct OnlineApp: App {
    @StateObject private var coordinator: AppCoordinator = {
        let coordinator = AppCoordinator()
        coordinator.start()
        return coordinator
    }()

    var body: some Scene {
        MenuBarExtra {
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

        Settings {
            SettingsView()
        }
    }
}
