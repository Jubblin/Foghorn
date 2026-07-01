import Foundation
import Network

final class PathProbe: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "online.path-probe")
    private var currentPath: NWPath?
    private let lock = NSLock()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            GatewayResolver.invalidate()
            self?.lock.lock()
            self?.currentPath = path
            self?.lock.unlock()
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
        let interfaces = path.availableInterfaces.map(\.name).joined(separator: ", ")
        let detail = satisfied ? "via \(interfaces)" : "status: \(path.status)"
        return SingleProbeResult(kind: .path, success: satisfied, detail: detail)
    }
}
