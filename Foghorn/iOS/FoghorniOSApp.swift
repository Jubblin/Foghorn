import SwiftUI

#if canImport(UIKit)
@main
struct FoghorniOSApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Must happen before the app finishes launching (#115).
        BackgroundMonitor.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            IOSHomeView()
                .environmentObject(coordinator)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                BackgroundMonitor.shared.start()
            case .background:
                BackgroundMonitor.shared.appDidEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
#endif
