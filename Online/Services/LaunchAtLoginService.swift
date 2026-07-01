import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginService {
    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        }
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
