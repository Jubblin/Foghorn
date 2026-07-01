import Foundation

enum GatewayResolver {
    private static let lock = NSLock()
    private static var cachedGateway: String?

    static func invalidate() {
        lock.lock()
        cachedGateway = nil
        lock.unlock()
    }

    static func gatewayAddress() async -> String? {
        lock.lock()
        if let cachedGateway {
            lock.unlock()
            return cachedGateway
        }
        lock.unlock()

        let resolved = DefaultRoute.gatewayAddress()
        lock.lock()
        cachedGateway = resolved
        lock.unlock()
        return resolved
    }
}
