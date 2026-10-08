import Foundation

/// The four layers the iPhone home screen draws as a ladder, Phone → Router → DNS →
/// Internet (DESIGN.md → iPhone, #156). Only the first failing layer is lit; layers
/// after it were never reached, so they are not reported as working or broken.
struct LayerLadder: Equatable {
    enum Layer: String, CaseIterable, Identifiable {
        case phone
        case router
        case dns
        case internet

        var id: String { rawValue }

        var title: String {
            switch self {
            case .phone: return "Phone"
            case .router: return "Router"
            case .dns: return "DNS"
            case .internet: return "Internet"
            }
        }
    }

    enum RungState: String, Equatable {
        case passed
        case failed
        case degraded
        case notReached
        /// The probe was skipped (iOS often can't see the gateway), so say nothing either way.
        case notChecked
        case checking
        /// No probe has finished yet this launch.
        case waiting
    }

    struct Rung: Equatable, Identifiable {
        let layer: Layer
        let state: RungState
        let detail: String

        var id: Layer { layer }
    }

    let rungs: [Rung]

    /// The one rung that carries colour, if any.
    var litLayer: Layer? {
        rungs.first { $0.state == .failed || $0.state == .degraded }?.layer
    }

    init(status: ConnectivityStatus, isChecking: Bool = false) {
        guard !isChecking else {
            rungs = Layer.allCases.map { Rung(layer: $0, state: .checking, detail: "checking") }
            return
        }
        guard let snapshot = status.lastSnapshot else {
            rungs = Layer.allCases.map { Rung(layer: $0, state: .waiting, detail: "waiting") }
            return
        }

        let reason = status.state == .healthy ? nil : (status.failureReason ?? snapshot.failureReason())
        let lit = reason.map(Self.layer(for:))
        let tone: RungState = status.state == .outage ? .failed : .degraded

        var reachedLit = false
        rungs = Layer.allCases.map { layer in
            if reachedLit {
                return Rung(layer: layer, state: .notReached, detail: "not reached")
            }
            if layer == lit, let reason {
                reachedLit = true
                return Rung(layer: layer, state: tone, detail: Self.failureDetail(reason, host: status.customHost))
            }
            return Self.passingRung(layer, snapshot: snapshot)
        }
    }

    static func layer(for reason: FailureReason) -> Layer {
        switch reason {
        case .noInterface: return .phone
        case .routerUnreachable: return .router
        case .dnsFailure: return .dns
        case .ispOutage, .captivePortalLikely, .customHostDown: return .internet
        }
    }

    private static func failureDetail(_ reason: FailureReason, host: String?) -> String {
        switch reason {
        case .noInterface: return "no network"
        case .routerUnreachable: return "no answer"
        case .dnsFailure: return "no answer"
        case .ispOutage: return "unreachable"
        case .captivePortalLikely: return "captive portal"
        case .customHostDown: return "\(host ?? "custom host") down"
        }
    }

    private static func passingRung(_ layer: Layer, snapshot: ProbeSnapshot) -> Rung {
        switch layer {
        case .phone:
            return Rung(layer: layer, state: .passed, detail: trimmed(snapshot.result(for: .path)?.detail) ?? "up")
        case .router:
            let detail = trimmed(snapshot.result(for: .gateway)?.detail)
            if detail?.contains("skipped") == true {
                return Rung(layer: layer, state: .notChecked, detail: "not checked")
            }
            return Rung(layer: layer, state: .passed, detail: detail ?? "ok")
        case .dns, .internet:
            return Rung(layer: layer, state: .passed, detail: "ok")
        }
    }

    private static func trimmed(_ text: String?) -> String? {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}
