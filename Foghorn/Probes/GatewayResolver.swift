import Foundation
import SystemConfiguration

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

        let resolved = SCDynamicStoreGatewayResolver.defaultGatewayAddress()
        lock.lock()
        cachedGateway = resolved
        lock.unlock()
        return resolved
    }
}

enum SCDynamicStoreGatewayResolver {
    static func defaultGatewayAddress() -> String? {
        let store = SCDynamicStoreCreate(nil, "com.online.menu.gateway" as CFString, nil, nil)
        guard let store else { return nil }

        if let router = routerFromGlobalState(store: store, key: "State:/Network/Global/IPv4") {
            return router
        }
        if let router = routerFromGlobalState(store: store, key: "State:/Network/Global/IPv6") {
            return router
        }

        return nil
    }

    private static func routerFromGlobalState(store: SCDynamicStore, key: String) -> String? {
        guard let globalState = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
              let primaryService = globalState["PrimaryService"] as? String else {
            return nil
        }

        return routerFromService(store: store, serviceID: primaryService)
    }

    private static func routerFromService(store: SCDynamicStore, serviceID: String) -> String? {
        let ipv4Key = "State:/Network/Service/\(serviceID)/IPv4" as CFString
        if let ipv4 = SCDynamicStoreCopyValue(store, ipv4Key) as? [String: Any],
           let router = ipv4["Router"] as? String,
           !router.isEmpty {
            return router
        }

        let ipv6Key = "State:/Network/Service/\(serviceID)/IPv6" as CFString
        if let ipv6 = SCDynamicStoreCopyValue(store, ipv6Key) as? [String: Any],
           let router = ipv6["Router"] as? String,
           !router.isEmpty {
            return router
        }

        return nil
    }
}
