import SwiftUI

#if canImport(UIKit)
@main
struct FoghorniOSApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            iOSHomeView()
                .environmentObject(coordinator)
        }
    }
}
#endif

