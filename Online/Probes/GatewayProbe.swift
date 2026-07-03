import Foundation

protocol GatewayResolving {
    func gatewayAddress() async -> String?
}

protocol GatewayReachabilityChecking {
    func isReachable(host: String, timeoutMilliseconds: Int) async -> Bool
}

enum GatewayProbe {
    private static let pingTimeoutMilliseconds = 2_000
    private static var resolver: GatewayResolving = DefaultGatewayResolver()
    private static var reachability: GatewayReachabilityChecking = ICMPGatewayReachability()

    static func injectResolverForTesting(_ resolver: GatewayResolving?) {
        self.resolver = resolver ?? DefaultGatewayResolver()
    }

    static func injectReachabilityForTesting(_ reachability: GatewayReachabilityChecking?) {
        self.reachability = reachability ?? ICMPGatewayReachability()
    }

    static func probe() async -> SingleProbeResult {
        guard let gateway = await resolver.gatewayAddress() else {
            return SingleProbeResult(kind: .gateway, success: true, detail: "no gateway (skipped)")
        }

        let reachable = await reachability.isReachable(host: gateway, timeoutMilliseconds: pingTimeoutMilliseconds)
        return SingleProbeResult(
            kind: .gateway,
            success: reachable,
            detail: reachable ? gateway : "unreachable \(gateway)"
        )
    }
}

struct DefaultGatewayResolver: GatewayResolving {
    func gatewayAddress() async -> String? {
        await GatewayResolver.gatewayAddress()
    }
}

struct ICMPGatewayReachability: GatewayReachabilityChecking {
    func isReachable(host: String, timeoutMilliseconds: Int) async -> Bool {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", String(timeoutMilliseconds), host]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
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
