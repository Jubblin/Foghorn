import Foundation
import UserNotifications

@MainActor
final class AlertService: NSObject, ObservableObject {
    static let shared = AlertService()

    @Published private(set) var isAuthorized = false

    private override init() {
        super.init()
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                isAuthorized = granted
            } catch {
                isAuthorized = false
            }
        default:
            isAuthorized = false
        }
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
