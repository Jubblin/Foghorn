import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

@MainActor
enum LaunchAtLoginService {
    static func setEnabled(_ enabled: Bool) throws {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        }
        #else
        // No "launch at login" equivalent on iOS.
        _ = enabled
        #endif
    }

    static var isEnabled: Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
        #else
        return false
        #endif
    }
}
