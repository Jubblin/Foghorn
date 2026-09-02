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
        didSet { UITestConfiguration.defaults.set(customHosts, forKey: Keys.customHosts) }
    }

    @Published var launchAtLogin: Bool {
        didSet { UITestConfiguration.defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var basePollInterval: TimeInterval {
        didSet { UITestConfiguration.defaults.set(basePollInterval, forKey: Keys.pollInterval) }
    }

    /// When false, the menu bar icon is hidden but probes and notifications keep running.
    @Published var showInMenuBar: Bool {
        didSet { UITestConfiguration.defaults.set(showInMenuBar, forKey: Keys.showInMenuBar) }
    }

    @Published var appearancePreference: AppearancePreference {
        didSet {
            UITestConfiguration.defaults.set(appearancePreference.rawValue, forKey: Keys.appearancePreference)
            guard !isRestoringDefaults else { return }
            Self.applyAppKitAppearance(appearancePreference)
        }
    }

    /// When true, Foghorn checks for updates about once per day (Sparkle on Developer ID builds).
    @Published var automaticUpdatesEnabled: Bool {
        didSet {
            UITestConfiguration.defaults.set(automaticUpdatesEnabled, forKey: Keys.automaticUpdatesEnabled)
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
            UITestConfiguration.defaults.set(includePrereleaseUpdates, forKey: Keys.includePrereleaseUpdates)
            guard !isRestoringDefaults else { return }
            AppUpdateService.shared.applyChannelPreferences()
        }
    }

    private var isRestoringDefaults = true

    private init() {
        customHosts = UITestConfiguration.defaults.stringArray(forKey: Keys.customHosts) ?? []
        launchAtLogin = UITestConfiguration.defaults.bool(forKey: Keys.launchAtLogin)
        let stored = UITestConfiguration.defaults.double(forKey: Keys.pollInterval)
        basePollInterval = stored > 0 ? stored : 2.0
        if UITestConfiguration.defaults.object(forKey: Keys.showInMenuBar) == nil {
            showInMenuBar = true
        } else {
            showInMenuBar = UITestConfiguration.defaults.bool(forKey: Keys.showInMenuBar)
        }

        if let raw = UITestConfiguration.defaults.string(forKey: Keys.appearancePreference),
           let stored = AppearancePreference(rawValue: raw) {
            appearancePreference = stored
        } else {
            appearancePreference = .system
        }

        if UITestConfiguration.defaults.object(forKey: Keys.automaticUpdatesEnabled) == nil {
            automaticUpdatesEnabled = true
        } else {
            automaticUpdatesEnabled = UITestConfiguration.defaults.bool(forKey: Keys.automaticUpdatesEnabled)
        }

        includePrereleaseUpdates = UITestConfiguration.defaults.bool(forKey: Keys.includePrereleaseUpdates)
        isRestoringDefaults = false
        // Do not touch NSApp.appearance here — XCTest host bootstrap crashes if we
        // mutate appearance before the application finishes launching.
    }

    /// SwiftUI `preferredColorScheme(nil)` often stays stuck after Light/Dark; drive AppKit too.
    static func applyAppKitAppearance(_ preference: AppearancePreference) {
        #if canImport(AppKit)
        // Skip under xcodebuild test host bootstrap (mutating NSApp too early crashes).
        guard !UITestConfiguration.isXCTestProcess else { return }

        let apply = {
            switch preference {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
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
