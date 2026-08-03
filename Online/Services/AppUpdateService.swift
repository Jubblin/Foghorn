import AppKit
import Foundation
import UserNotifications

enum AppUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(current: String)
    case available(AppRelease)
    case failed(String)
}

@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    @Published private(set) var status: AppUpdateStatus = .idle
    @Published private(set) var lastCheckedAt: Date?

    private let client: AppReleaseFetching
    private let currentVersionProvider: () -> String
    private let architecture: AppArchitecture
    private let notificationCenter: UNUserNotificationCenter
    private var automaticCheckTask: Task<Void, Never>?

    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    private static let updateNotificationID = "online.app-update.available"

    init(
        client: AppReleaseFetching = GitHubReleaseClient(),
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
    }

    func startAutomaticChecksIfNeeded() {
        automaticCheckTask?.cancel()
        guard AppSettings.shared.automaticUpdatesEnabled else { return }
        guard !UITestConfiguration.isActive, !UITestConfiguration.isXCTestProcess else { return }

        automaticCheckTask = Task { [weak self] in
            // Defer first check briefly so launch probes aren't competing for bandwidth.
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                guard AppSettings.shared.automaticUpdatesEnabled else { return }
                _ = await self.checkForUpdates(userInitiated: false)
                try? await Task.sleep(nanoseconds: UInt64(Self.automaticCheckInterval * 1_000_000_000))
            }
        }
    }

    func stopAutomaticChecks() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil
    }

    @discardableResult
    func checkForUpdates(userInitiated: Bool) async -> AppUpdateStatus {
        guard !UITestConfiguration.isActive, !UITestConfiguration.isXCTestProcess else {
            status = .upToDate(current: currentVersionProvider())
            return status
        }

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

    func openAvailableUpdate() {
        guard case let .available(release) = status else {
            AppLinks.openInBrowser(AppLinks.releases)
            return
        }
        let url = release.preferredDownloadURL(architecture: architecture) ?? release.htmlURL
        AppLinks.openInBrowser(url)
    }

    func presentManualCheckResult() {
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
    }

    var statusSummary: String {
        switch status {
        case .idle:
            return "Not checked yet"
        case .checking:
            return "Checking GitHub Releases…"
        case .upToDate(let current):
            return "Online \(current) is the latest release."
        case .available(let release):
            return "Online \(Self.labeledVersion(release)) is available (you have \(currentVersionProvider()))."
        case .failed(let message):
            return message
        }
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
        content.body = "Online \(Self.labeledVersion(release)) is ready to download."
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
