import AppKit
import Foundation
import UserNotifications

enum NotificationAuthorizationDisplay: Equatable {
    case granted
    case notDetermined
    case denied

    var statusText: String {
        switch self {
        case .granted:
            return "Alerts enabled"
        case .notDetermined:
            return "Not set up"
        case .denied:
            return "Denied"
        }
    }
}

@MainActor
final class AlertService: NSObject, ObservableObject {
    static let shared = AlertService()

    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationDisplay: NotificationAuthorizationDisplay = .notDetermined

    private override init() {
        super.init()
    }

    func applyUITestAuthorization(_ display: NotificationAuthorizationDisplay) {
        authorizationDisplay = display
        isAuthorized = display == .granted
    }

    func refreshAuthorizationStatus() async {
        if UITestConfiguration.isActive, let mock = UITestConfiguration.mockNotificationAuthorization {
            applyUITestAuthorization(mock)
            return
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
            authorizationDisplay = .granted
        case .notDetermined:
            isAuthorized = false
            authorizationDisplay = .notDetermined
        case .denied:
            isAuthorized = false
            authorizationDisplay = .denied
        @unknown default:
            isAuthorized = false
            authorizationDisplay = .denied
        }
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
            authorizationDisplay = .granted
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                isAuthorized = granted
                authorizationDisplay = granted ? .granted : .denied
            } catch {
                isAuthorized = false
                authorizationDisplay = .denied
            }
        default:
            isAuthorized = false
            authorizationDisplay = .denied
        }
    }

    static func openSystemNotificationSettings() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func notifyOutage(record: OutageRecord) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Connection lost"
        content.body = record.reasonDetail
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "outage-\(record.id.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyRestored(duration: TimeInterval) {
        guard isAuthorized else { return }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationText: String
        if minutes > 0 {
            durationText = "\(minutes)m \(seconds)s"
        } else {
            durationText = "\(seconds)s"
        }

        let content = UNMutableNotificationContent()
        content.title = "Back online"
        content.body = "Connection restored after \(durationText)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "restored-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

extension AlertService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
