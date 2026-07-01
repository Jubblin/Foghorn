import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let customHosts = "customHosts"
        static let launchAtLogin = "launchAtLogin"
        static let pollInterval = "pollInterval"
    }

    @Published var customHosts: [String] {
        didSet { UserDefaults.standard.set(customHosts, forKey: Keys.customHosts) }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var basePollInterval: TimeInterval {
        didSet { UserDefaults.standard.set(basePollInterval, forKey: Keys.pollInterval) }
    }

    private init() {
        customHosts = UserDefaults.standard.stringArray(forKey: Keys.customHosts) ?? []
        launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        let stored = UserDefaults.standard.double(forKey: Keys.pollInterval)
        basePollInterval = stored > 0 ? stored : 2.0
    }

    func addCustomHost(_ host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customHosts.contains(trimmed) else { return }
        customHosts.append(trimmed)
    }

    func removeCustomHost(at offsets: IndexSet) {
        customHosts.remove(atOffsets: offsets)
    }
}
