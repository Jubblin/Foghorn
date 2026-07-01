import Foundation
import Network

enum GatewayProbe {
    static func probe() async -> SingleProbeResult {
        guard let gateway = await GatewayResolver.gatewayAddress() else {
            return SingleProbeResult(kind: .gateway, success: true, detail: "no gateway (skipped)")
        }

        let reachable = await tcpReachable(host: gateway, port: 80, timeout: 2)
        if reachable {
            return SingleProbeResult(kind: .gateway, success: true, detail: gateway)
        }

        let fallback = await tcpReachable(host: gateway, port: 443, timeout: 2)
        return SingleProbeResult(
            kind: .gateway,
            success: fallback,
            detail: fallback ? gateway : "unreachable \(gateway)"
        )
    }

    private static func tcpReachable(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let nwHost = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
            let queue = DispatchQueue(label: "online.gateway-\(host)-\(port)")
            var finished = false

            func finish(_ value: Bool) {
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(false)
            }
        }
    }
}

enum DefaultRoute {
    static func gatewayAddress() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("gateway:") {
                return trimmed
                    .replacingOccurrences(of: "gateway:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
