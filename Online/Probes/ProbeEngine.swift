import Combine
import Foundation
import IOKit.ps

@MainActor
final class ProbeEngine: ObservableObject {
    @Published private(set) var latestSnapshot: ProbeSnapshot?
    @Published private(set) var isRunning = false

    private let pathProbe = PathProbe()
    private var tickTask: Task<Void, Never>?
    private var onTick: ((ProbeSnapshot) -> Void)?

    private var currentInterval: TimeInterval = 2.0

    func start(onTick: @escaping (ProbeSnapshot) -> Void) {
        guard tickTask == nil else { return }
        self.onTick = onTick
        isRunning = true
        currentInterval = AppSettings.shared.basePollInterval

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runTick()
                let interval = await self.effectiveInterval()
                self.currentInterval = interval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
    }

    func runTickNow() async {
        await runTick()
    }

    private func runTick() async {
        let pathResult = pathProbe.evaluate()

        async let gateway = GatewayProbe.probe()
        async let dns = DNSProbe.probe()
        async let httpPrimary = HTTPProbe.probePrimary()
        async let httpSecondary = HTTPProbe.probeSecondary()
        async let custom = CustomHostProbe.probe(hosts: AppSettings.shared.customHosts)

        let gatewayResult = await gateway
        let dnsResult = await dns
        let primaryResult = await httpPrimary
        let secondaryResult = await httpSecondary
        let customResults = await custom

        var results = [pathResult, gatewayResult, dnsResult, primaryResult, secondaryResult]
        results.append(contentsOf: customResults)

        let snapshot = ProbeSnapshot(timestamp: Date(), results: results)
        latestSnapshot = snapshot
        onTick?(snapshot)
    }

    private func effectiveInterval() -> TimeInterval {
        let base = AppSettings.shared.basePollInterval
        guard PowerSource.isOnBattery else { return base }

        switch base {
        case ..<3:
            return min(base * 2, 8)
        case 3 ..< 6:
            return min(base * 1.5, 8)
        default:
            return min(base, 8)
        }
    }
}

enum PowerSource {
    static var isOnBattery: Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let state = description[kIOPSPowerSourceStateKey] as? String
        else {
            return false
        }
        return state == kIOPSBatteryPowerValue
    }
}
