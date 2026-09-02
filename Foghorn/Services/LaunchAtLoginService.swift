import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

#if canImport(AppKit)
import AppKit
#endif

@MainActor
enum LaunchAtLoginService {
    /// What macOS currently does, as opposed to what the user asked for. The two
    /// diverge when an in-place update replaces the bundle that registered the
    /// login item (#101), so they are tracked separately.
    enum Status: Equatable {
        case enabled
        /// The item exists but is waiting on the user in System Settings.
        case requiresApproval
        case notRegistered
        /// No launch-at-login concept on this platform.
        case unsupported
    }

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

    static var status: Status {
        #if canImport(ServiceManagement)
        guard #available(macOS 13.0, *) else { return .unsupported }
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        default:
            // .notRegistered, .notFound, and anything added later.
            return .notRegistered
        }
        #else
        return .unsupported
        #endif
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    /// Re-registers when the stored preference says on but macOS has dropped the
    /// registration — what an in-place update does (#101). Losing the registration
    /// is not the user changing their mind, so it is repaired rather than recorded.
    ///
    /// `.requiresApproval` is left alone: only the user can grant that, in System
    /// Settings, and re-registering would not move it along.
    @discardableResult
    static func restoreIfNeeded(intent: Bool) -> Status {
        guard shouldRestore(intent: intent, status: status) else { return status }
        try? setEnabled(true)
        return status
    }

    /// Split out from `restoreIfNeeded` so the decision is testable without
    /// SMAppService, which cannot be driven from a test.
    static func shouldRestore(intent: Bool, status: Status) -> Bool {
        intent && status == .notRegistered
    }

    /// System Settings → General → Login Items, for the approval case.
    static func openSystemLoginItemsSettings() {
        #if canImport(AppKit)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
        #endif
    }
}
