import Foundation

struct OutageRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let reason: FailureReason
    let reasonDetail: String

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var durationDescription: String {
        guard let duration else { return "ongoing" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        reason: FailureReason,
        reasonDetail: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.reason = reason
        self.reasonDetail = reasonDetail
    }
}
