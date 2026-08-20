import SwiftUI

#if canImport(UIKit)
@main
struct FoghorniOSApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            IOSHomeView()
                .environmentObject(coordinator)
        }
    }
}
#endif
