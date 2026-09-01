import Foundation
import Network
import os

final class PathProbe: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "online.path-probe")
    private var currentPath: NWPath?
    private var lastInterfaceSignature: String?
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.online.menu", category: "path")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            GatewayResolver.invalidate()
            self?.lock.lock()
            self?.currentPath = path
            let signature = Self.interfaceSignature(for: path)
            let previous = self?.lastInterfaceSignature
            self?.lastInterfaceSignature = signature
            self?.lock.unlock()

            if let previous, previous != signature {
                self?.logger.info(
                    "Network path interfaces changed: \(previous, privacy: .public) → \(signature, privacy: .public)"
                )
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func evaluate() -> SingleProbeResult {
        lock.lock()
        let path = currentPath
        lock.unlock()

        guard let path else {
            return SingleProbeResult(kind: .path, success: false, detail: "monitor not ready")
        }

        let satisfied = path.status == .satisfied
        let interfaces = Self.interfaceLabels(for: path).joined(separator: ", ")
        let detail = satisfied
            ? (interfaces.isEmpty ? "ok" : "via \(interfaces)")
            : Self.unsatisfiedDetail(for: path)
        return SingleProbeResult(kind: .path, success: satisfied, detail: detail)
    }

    /// Concise evidence phrase for a down path, per DESIGN.md probe-row voice
    /// (`PATH via en4/wired`, not a raw enum dump like `status: unsatisfied`).
    private static func unsatisfiedDetail(for path: NWPath) -> String {
        if path.status == .requiresConnection {
            return "connection required"
        }
        switch path.unsatisfiedReason {
        case .cellularDenied:
            return "cellular access denied"
        case .wifiDenied:
            return "wifi access denied"
        case .localNetworkDenied:
            return "local network denied"
        case .vpnInactive:
            return "vpn inactive"
        case .notAvailable:
            return "no interfaces"
        @unknown default:
            return "unavailable"
        }
    }

    /// Host strings from `NWPath.gateways` (no Local Network TCC required).
    func gatewayHostStrings() -> [String] {
        lock.lock()
        let path = currentPath
        lock.unlock()

        guard let path else { return [] }
        return path.gateways.compactMap(Self.hostString(from:))
    }

    private static func interfaceSignature(for path: NWPath) -> String {
        interfaceLabels(for: path).joined(separator: ",")
    }

    private static func interfaceLabels(for path: NWPath) -> [String] {
        path.availableInterfaces.map(interfaceLabel)
    }

    private static func interfaceLabel(_ interface: NWInterface) -> String {
        "\(interface.name)/\(interfaceTypeLabel(interface.type))"
    }

    private static func interfaceTypeLabel(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi:
            return "wifi"
        case .wiredEthernet:
            return "wired"
        case .cellular:
            return "cellular"
        case .loopback:
            return "loopback"
        case .other:
            return "other"
        @unknown default:
            return "other"
        }
    }

    private static func hostString(from endpoint: NWEndpoint) -> String? {
        switch endpoint {
        case .hostPort(let host, _):
            return "\(host)"
        case .unix, .url, .opaque:
            return nil
        @unknown default:
            return nil
        }
    }
}
