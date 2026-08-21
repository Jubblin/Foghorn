import Foundation
import UserNotifications

#if canImport(AppKit)
import AppKit
#endif

#if canImport(Sparkle) && !APP_STORE
import Sparkle
#endif

enum AppUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(current: String)
    case available(AppRelease)
    case failed(String)
}

@MainActor
final class AppUpdateService: NSObject, ObservableObject {
    static let shared = AppUpdateService()

    @Published private(set) var status: AppUpdateStatus = .idle
    @Published private(set) var lastCheckedAt: Date?

    private let currentVersionProvider: () -> String
    private let notificationCenter: UNUserNotificationCenter

#if canImport(Sparkle) && !APP_STORE
    private var updaterController: SPUStandardUpdaterController?
#endif

    /// Legacy GitHub client retained for unit-testable selection helpers / APP_STORE stub.
    private let client: GitHubReleaseClient
    private let architecture: AppArchitecture
    private var automaticCheckTask: Task<Void, Never>?

    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    private static let updateNotificationID = "foghorn.app-update.available"
    nonisolated private static let prereleaseChannel = "prerelease"

    init(
        client: GitHubReleaseClient = GitHubReleaseClient(),
        currentVersionProvider: @escaping () -> String = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        },
        architecture: AppArchitecture = .current,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.client = client
        self.currentVersionProvider = currentVersionProvider
        self.architecture = architecture
        self.notificationCenter = notificationCenter
        super.init()

#if canImport(Sparkle) && !APP_STORE
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
#endif
    }

    func startAutomaticChecksIfNeeded() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil

        guard AppSettings.shared.automaticUpdatesEnabled else { return }
        guard !UITestConfiguration.isActive, !UITestConfiguration.isXCTestProcess else { return }

#if canImport(Sparkle) && !APP_STORE
        guard let updater = updaterController?.updater else { return }
        applyPreferencesToUpdater(updater)
        do {
            try updater.start()
        } catch {
            status = .failed(error.localizedDescription)
        }
#else
        // App Store / no Sparkle: fall back to notify-only GitHub checks.
        automaticCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                guard AppSettings.shared.automaticUpdatesEnabled else { return }
                _ = await self.checkForUpdatesUsingGitHub(userInitiated: false)
                try? await Task.sleep(nanoseconds: UInt64(Self.automaticCheckInterval * 1_000_000_000))
            }
        }
#endif
    }

    func stopAutomaticChecks() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil

#if canImport(Sparkle) && !APP_STORE
        updaterController?.updater.automaticallyChecksForUpdates = false
#endif
    }

    func applyChannelPreferences() {
#if canImport(Sparkle) && !APP_STORE
        guard let updater = updaterController?.updater else { return }
        applyPreferencesToUpdater(updater)
#endif
    }

    @discardableResult
    func checkForUpdates(userInitiated: Bool) async -> AppUpdateStatus {
        guard !UITestConfiguration.isActive, !UITestConfiguration.isXCTestProcess else {
            status = .upToDate(current: currentVersionProvider())
            return status
        }

#if canImport(Sparkle) && !APP_STORE
        guard let controller = updaterController else {
            status = .failed("Updater is not available.")
            return status
        }
        applyPreferencesToUpdater(controller.updater)
        status = .checking
        if userInitiated {
            controller.checkForUpdates(nil)
        } else if controller.updater.automaticallyChecksForUpdates {
            controller.updater.checkForUpdatesInBackground()
        }
        return status
#else
        return await checkForUpdatesUsingGitHub(userInitiated: userInitiated)
#endif
    }

    func openAvailableUpdate() {
#if canImport(Sparkle) && !APP_STORE
        updaterController?.checkForUpdates(nil)
#else
        guard case let .available(release) = status else {
            AppLinks.openInBrowser(AppLinks.releases)
            return
        }
        let url = release.preferredDownloadURL(architecture: architecture) ?? release.htmlURL
        AppLinks.openInBrowser(url)
#endif
    }

    func presentManualCheckResult() {
#if canImport(Sparkle) && !APP_STORE
        // Sparkle presents its own update UI from checkForUpdates(_:).
        return
#else
        #if canImport(AppKit)
        switch status {
        case .available:
            let alert = NSAlert()
            alert.messageText = "Update available"
            alert.informativeText = statusSummary
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                openAvailableUpdate()
            }
        case .upToDate, .checking, .idle:
            let alert = NSAlert()
            alert.messageText = "You're up to date"
            alert.informativeText = statusSummary
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .failed:
            let alert = NSAlert()
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = statusSummary
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Releases")
            if alert.runModal() == .alertSecondButtonReturn {
                AppLinks.openInBrowser(AppLinks.releases)
            }
        }
        #else
        // iOS doesn't have a drop-in equivalent for the AppKit modal prompt.
        // Keep this method as a no-op; update information can be surfaced via
        // notifications or in-app UI later.
        #endif
#endif
    }

    var statusSummary: String {
        switch status {
        case .idle:
            return "Not checked yet"
        case .checking:
            return "Checking for updates…"
        case .upToDate(let current):
            return "Foghorn \(current) is up to date."
        case .available(let release):
            return "Foghorn \(Self.labeledVersion(release)) is available (you have \(currentVersionProvider()))."
        case .failed(let message):
            return message
        }
    }

#if canImport(Sparkle) && !APP_STORE
    private func applyPreferencesToUpdater(_ updater: SPUUpdater) {
        updater.automaticallyChecksForUpdates = AppSettings.shared.automaticUpdatesEnabled
        updater.updateCheckInterval = Self.automaticCheckInterval
        // Channel filtering is via SPUUpdaterDelegate.allowedChannels(for:).
    }
#endif

    @discardableResult
    private func checkForUpdatesUsingGitHub(userInitiated: Bool) async -> AppUpdateStatus {
        status = .checking
        do {
            let releases = try await client.fetchReleases()
            let current = currentVersionProvider()
            lastCheckedAt = Date()

            if let update = AppUpdateSelection.latestAvailableUpdate(
                in: releases,
                currentVersion: current,
                includePrereleases: AppSettings.shared.includePrereleaseUpdates
            ) {
                status = .available(update)
                if !userInitiated {
                    await postUpdateNotification(for: update)
                }
            } else {
                status = .upToDate(current: current)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
        return status
    }

    private func postUpdateNotification(for release: AppRelease) async {
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Update available"
        content.body = "Foghorn \(Self.labeledVersion(release)) is ready to install."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.updateNotificationID,
            content: content,
            trigger: nil
        )
        try? await notificationCenter.add(request)
    }

    private static func labeledVersion(_ release: AppRelease) -> String {
        if release.isPrerelease || release.isContinuousBuild {
            return "\(release.versionString) pre-release"
        }
        return release.versionString
    }
}

#if canImport(Sparkle) && !APP_STORE
extension AppUpdateService: SPUUpdaterDelegate {
    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        _ = updater
        // Default channel is always included by Sparkle; only add extras here.
        // Read UserDefaults directly so this stays safe off the main actor.
        if UserDefaults.standard.bool(forKey: "includePrereleaseUpdates") {
            return [Self.prereleaseChannel]
        }
        return []
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        _ = updater
        Task { @MainActor in
            lastCheckedAt = Date()
            let version = item.displayVersionString
            let tag = version.hasPrefix("v") ? version : "v\(version)"
            let channel = item.channel ?? ""
            let release = AppRelease(
                tagName: tag,
                name: item.title,
                htmlURL: item.infoURL ?? AppLinks.releases,
                isPrerelease: !channel.isEmpty,
                publishedAt: item.date,
                assets: [
                    AppReleaseAsset(
                        name: item.fileURL?.lastPathComponent ?? "Foghorn-update.zip",
                        downloadURL: item.fileURL ?? AppLinks.releases
                    )
                ]
            )
            status = .available(release)
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        _ = updater
        Task { @MainActor in
            lastCheckedAt = Date()
            let nsError = error as NSError
            if nsError.domain == SUSparkleErrorDomain,
               nsError.code == Int(SUError.noUpdateError.rawValue) {
                status = .upToDate(current: currentVersionProvider())
            } else if nsError.code == Int(SUError.installationCanceledError.rawValue) {
                status = .idle
            } else {
                status = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        _ = updater
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == SUSparkleErrorDomain,
               nsError.code == Int(SUError.installationCanceledError.rawValue) {
                return
            }
            status = .failed(error.localizedDescription)
        }
    }
}
#endif
