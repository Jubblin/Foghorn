import Foundation

enum ConnectivityState: String, Equatable {
    case healthy
    case degraded
    case outage
    case recovering

    var displayName: String {
        switch self {
        case .healthy:
            return "Online"
        case .degraded:
            return "Degraded"
        case .outage:
            return "Offline"
        case .recovering:
            return "Recovering"
        }
    }

    /// Traffic-light menu bar indicator (always `circle.fill`; color encodes state).
    var menuBarSymbol: String {
        "circle.fill"
    }

    var showsAlert: Bool {
        switch self {
        case .outage:
            return true
        case .healthy, .degraded, .recovering:
            return false
        }
    }
}

struct ConnectivityStatus: Equatable {
    var state: ConnectivityState
    var lastSnapshot: ProbeSnapshot?
    var failureReason: FailureReason?
    var customHost: String?
    var lastCheck: Date
    var outageStartedAt: Date?
    /// When the connection last settled into healthy, so the popover can stop
    /// restating the obvious once nothing has gone wrong for a while (#106).
    var healthySince: Date?

    static let initial = ConnectivityStatus(
        state: .healthy,
        lastSnapshot: nil,
        failureReason: nil,
        customHost: nil,
        lastCheck: Date(),
        outageStartedAt: nil,
        healthySince: nil
    )
}
