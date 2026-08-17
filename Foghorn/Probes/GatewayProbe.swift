import Foundation
import Network

protocol GatewayResolving {
    func gatewayAddress() async -> String?
}

protocol GatewayReachabilityChecking {
    func isReachable(host: String, timeoutMilliseconds: Int) async -> Bool
}

enum GatewayProbe {
    private static let reachabilityTimeoutMilliseconds = 2_000
    private static var resolver: GatewayResolving = DefaultGatewayResolver()
    private static var reachability: GatewayReachabilityChecking = NWGatewayReachability()

    static func injectResolverForTesting(_ resolver: GatewayResolving?) {
        self.resolver = resolver ?? DefaultGatewayResolver()
    }

    static func injectReachabilityForTesting(_ reachability: GatewayReachabilityChecking?) {
        self.reachability = reachability ?? NWGatewayReachability()
    }

    /// - Parameter pathGateways: Hosts from `NWPath.gateways`. When the resolved
    ///   gateway appears here, skip LAN TCP (avoids false fails under Local Network privacy).
    static func probe(pathGateways: [String] = []) async -> SingleProbeResult {
        guard let gateway = await resolver.gatewayAddress() else {
            if let pathGateway = pathGateways.first {
                return SingleProbeResult(kind: .gateway, success: true, detail: pathGateway)
            }
            return SingleProbeResult(kind: .gateway, success: true, detail: "no gateway (skipped)")
        }

        if pathGateways.contains(where: { hostsMatch($0, gateway) }) {
            return SingleProbeResult(kind: .gateway, success: true, detail: gateway)
        }

        let reachable = await reachability.isReachable(
            host: gateway,
            timeoutMilliseconds: reachabilityTimeoutMilliseconds
        )
        return SingleProbeResult(
            kind: .gateway,
            success: reachable,
            detail: reachable ? gateway : "unreachable \(gateway)"
        )
    }

    private static func hostsMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

struct DefaultGatewayResolver: GatewayResolving {
    func gatewayAddress() async -> String? {
        await GatewayResolver.gatewayAddress()
    }
}

enum GatewayReachabilityEvaluator {
    /// `nil` means the connection is still in progress.
    static func evaluate(state: NWConnection.State) -> Bool? {
        switch state {
        case .ready:
            return true
        case .failed(let error):
            return evaluate(error: error)
        case .waiting(let error):
            return evaluate(error: error)
        case .cancelled, .preparing, .setup:
            return nil
        @unknown default:
            return nil
        }
    }

    static func evaluate(error: NWError) -> Bool? {
        switch error {
        case .posix(let code) where code == .ECONNREFUSED:
            return true
        case .posix(let code) where code == .EHOSTUNREACH || code == .ENETUNREACH || code == .ETIMEDOUT:
            return false
        default:
            return nil
        }
    }
}

struct NWGatewayReachability: GatewayReachabilityChecking {
    private let probePort: NWEndpoint.Port = 80

    func isReachable(host: String, timeoutMilliseconds: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: probePort,
                using: .tcp
            )

            let lock = NSLock()
            var resumed = false

            func resumeOnce(_ value: Bool) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                if let result = GatewayReachabilityEvaluator.evaluate(state: state) {
                    resumeOnce(result)
                }
            }

            connection.start(queue: .global(qos: .utility))

            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + .milliseconds(timeoutMilliseconds)
            ) {
                resumeOnce(false)
            }
        }
    }
}
