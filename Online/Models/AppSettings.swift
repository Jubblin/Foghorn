import Foundation

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let customHosts = "customHosts"
        static let launchAtLogin = "launchAtLogin"
        static let pollInterval = "pollInterval"
        static let showInMenuBar = "showInMenuBar"
        static let appearancePreference = "appearancePreference"
        static let automaticUpdatesEnabled = "automaticUpdatesEnabled"
        static let includePrereleaseUpdates = "includePrereleaseUpdates"
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

    /// When false, the menu bar icon is hidden but probes and notifications keep running.
    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: Keys.showInMenuBar) }
    }

    @Published var appearancePreference: AppearancePreference {
        didSet {
            UserDefaults.standard.set(appearancePreference.rawValue, forKey: Keys.appearancePreference)
            guard !isRestoringDefaults else { return }
            Self.applyAppKitAppearance(appearancePreference)
        }
    }

    /// When true, Online checks for updates about once per day (Sparkle on Developer ID builds).
    @Published var automaticUpdatesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticUpdatesEnabled, forKey: Keys.automaticUpdatesEnabled)
            guard !isRestoringDefaults else { return }
            if automaticUpdatesEnabled {
                AppUpdateService.shared.startAutomaticChecksIfNeeded()
            } else {
                AppUpdateService.shared.stopAutomaticChecks()
            }
        }
    }

    /// When true, update checks also consider the Sparkle `prerelease` channel (and GitHub fallback).
    @Published var includePrereleaseUpdates: Bool {
        didSet {
            UserDefaults.standard.set(includePrereleaseUpdates, forKey: Keys.includePrereleaseUpdates)
            guard !isRestoringDefaults else { return }
            AppUpdateService.shared.applyChannelPreferences()
        }
    }

    private var isRestoringDefaults = true

    private init() {
        customHosts = UserDefaults.standard.stringArray(forKey: Keys.customHosts) ?? []
        launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        let stored = UserDefaults.standard.double(forKey: Keys.pollInterval)
        basePollInterval = stored > 0 ? stored : 2.0
        if UserDefaults.standard.object(forKey: Keys.showInMenuBar) == nil {
            showInMenuBar = true
        } else {
            showInMenuBar = UserDefaults.standard.bool(forKey: Keys.showInMenuBar)
        }

        if let raw = UserDefaults.standard.string(forKey: Keys.appearancePreference),
           let stored = AppearancePreference(rawValue: raw) {
            appearancePreference = stored
        } else {
            appearancePreference = .system
        }

        if UserDefaults.standard.object(forKey: Keys.automaticUpdatesEnabled) == nil {
            automaticUpdatesEnabled = true
        } else {
            automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: Keys.automaticUpdatesEnabled)
        }

        includePrereleaseUpdates = UserDefaults.standard.bool(forKey: Keys.includePrereleaseUpdates)
        isRestoringDefaults = false
        Self.applyAppKitAppearance(appearancePreference)
    }

    /// SwiftUI `preferredColorScheme(nil)` often stays stuck after Light/Dark; drive AppKit too.
    static func applyAppKitAppearance(_ preference: AppearancePreference) {
        #if canImport(AppKit)
        switch preference {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
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
