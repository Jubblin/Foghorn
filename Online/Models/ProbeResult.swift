import Foundation

enum ProbeKind: String, Codable, CaseIterable {
    case path
    case gateway
    case dns
    case httpPrimary
    case httpSecondary
    case custom
}

struct SingleProbeResult: Equatable {
    let kind: ProbeKind
    let success: Bool
    let detail: String?
    let customHost: String?

    init(kind: ProbeKind, success: Bool, detail: String? = nil, customHost: String? = nil) {
        self.kind = kind
        self.success = success
        self.detail = detail
        self.customHost = customHost
    }
}

struct ProbeSnapshot: Equatable {
    let timestamp: Date
    let results: [SingleProbeResult]

    func result(for kind: ProbeKind) -> SingleProbeResult? {
        results.first { $0.kind == kind }
    }

    var pathSatisfied: Bool {
        result(for: .path)?.success ?? false
    }

    var gatewayOK: Bool {
        result(for: .gateway)?.success ?? false
    }

    var dnsOK: Bool {
        result(for: .dns)?.success ?? false
    }

    var httpPrimaryOK: Bool {
        result(for: .httpPrimary)?.success ?? false
    }

    var httpSecondaryOK: Bool {
        result(for: .httpSecondary)?.success ?? false
    }

    var customResults: [SingleProbeResult] {
        results.filter { $0.kind == .custom }
    }

    var allCustomOK: Bool {
        let customs = customResults
        return customs.isEmpty || customs.allSatisfy(\.success)
    }

    var allHTTPOK: Bool {
        httpPrimaryOK || httpSecondaryOK
    }

    var isFullyHealthy: Bool {
        pathSatisfied && gatewayOK && dnsOK && allHTTPOK && allCustomOK
    }

    var isCriticalFailure: Bool {
        !pathSatisfied || !allHTTPOK
    }

    var isPartialFailure: Bool {
        !isFullyHealthy && !isCriticalFailure
    }

    func failureReason() -> FailureReason? {
        if isFullyHealthy { return nil }

        if !pathSatisfied {
            return .noInterface
        }

        if !gatewayOK {
            return .routerUnreachable
        }

        let customs = customResults.filter { !$0.success }
        if !customs.isEmpty, customs.count == customResults.count, dnsOK, allHTTPOK {
            if customs.first?.customHost != nil {
                return .customHostDown
            }
        }

        if !dnsOK {
            return .dnsFailure
        }

        if let primary = result(for: .httpPrimary), !primary.success,
           primary.detail?.contains("redirect") == true || primary.detail?.contains("captive") == true {
            return .captivePortalLikely
        }

        if !allHTTPOK {
            return .ispOutage
        }

        if customs.first?.customHost != nil {
            return .customHostDown
        }

        return .ispOutage
    }
}

enum FailureReason: String, Codable, CaseIterable {
    case noInterface
    case routerUnreachable
    case dnsFailure
    case ispOutage
    case captivePortalLikely
    case customHostDown

    var displayName: String {
        switch self {
        case .noInterface:
            return "No network interface"
        case .routerUnreachable:
            return "Router unreachable"
        case .dnsFailure:
            return "DNS failure"
        case .ispOutage:
            return "ISP / internet outage"
        case .captivePortalLikely:
            return "Captive portal likely"
        case .customHostDown:
            return "Custom host unreachable"
        }
    }

    func message(host: String? = nil) -> String {
        switch self {
        case .customHostDown:
            return "Custom host down: \(host ?? "unknown")"
        default:
            return displayName
        }
    }
}
