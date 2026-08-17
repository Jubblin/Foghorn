import Foundation

@MainActor
final class ConnectivityStateMachine: ObservableObject {
    @Published private(set) var status: ConnectivityStatus = .initial

    private let evaluationWindow: TimeInterval = 15
    private let recoveryTicksRequired = 2
    private let criticalFailureTicks = 3

    private var unhealthySince: Date?
    private var degradedSince: Date?
    private var recoveryCleanTicks = 0
    private var consecutiveCriticalFailures = 0
    private var wakeGraceUntil: Date?
    private var currentOutageID: UUID?
    private var currentOutageProbeSummary: String?

    var onOutageStarted: ((OutageRecord) -> Void)?
    var onOutageEnded: ((OutageRecord, TimeInterval) -> Void)?
    var onStateChanged: ((ConnectivityStatus) -> Void)?

    func setWakeGrace(seconds: TimeInterval = 15) {
        wakeGraceUntil = Date().addingTimeInterval(seconds)
    }

    /// Re-attach to an outage that was still ongoing when the app last quit so a
    /// subsequent recovery can close it out with a real end time. Without this,
    /// a fresh launch starts with no `currentOutageID`, leaving the record stuck
    /// as "ongoing" forever.
    func adoptOngoingOutage(_ record: OutageRecord) {
        guard record.isOngoing else { return }
        currentOutageID = record.id
        currentOutageProbeSummary = record.probeSummary
        status.state = .outage
        status.outageStartedAt = record.startedAt
        status.failureReason = record.reason
    }

    func process(snapshot: ProbeSnapshot) {
        status.lastCheck = snapshot.timestamp
        status.lastSnapshot = snapshot

        if let wakeGraceUntil, Date() < wakeGraceUntil {
            return
        }

        if snapshot.isFullyHealthy {
            handleHealthy(snapshot: snapshot)
        } else if snapshot.isCriticalFailure {
            handleCriticalFailure(snapshot: snapshot)
        } else {
            handlePartialFailure(snapshot: snapshot)
        }

        onStateChanged?(status)
    }

    private func handleHealthy(snapshot: ProbeSnapshot) {
        consecutiveCriticalFailures = 0
        unhealthySince = nil
        degradedSince = nil
        status.failureReason = nil
        status.customHost = nil

        switch status.state {
        case .outage, .recovering:
            recoveryCleanTicks += 1
            if recoveryCleanTicks >= recoveryTicksRequired {
                completeRecovery()
            } else {
                status.state = .recovering
            }
        case .degraded:
            status.state = .healthy
        case .healthy:
            status.state = .healthy
        }
    }

    private func handleCriticalFailure(snapshot: ProbeSnapshot) {
        recoveryCleanTicks = 0
        degradedSince = nil
        consecutiveCriticalFailures += 1

        if unhealthySince == nil {
            unhealthySince = snapshot.timestamp
        }

        let reason = snapshot.failureReason()
        status.failureReason = reason
        status.customHost = reason == .customHostDown ? snapshot.customResults.first(where: { !$0.success })?.customHost : nil

        let sustained = snapshot.timestamp.timeIntervalSince(unhealthySince ?? snapshot.timestamp) >= evaluationWindow
        let rapid = consecutiveCriticalFailures >= criticalFailureTicks

        if sustained || rapid {
            transitionToOutage(snapshot: snapshot, reason: reason)
        } else if status.state == .healthy {
            status.state = .degraded
        }
    }

    private func handlePartialFailure(snapshot: ProbeSnapshot) {
        consecutiveCriticalFailures = 0
        recoveryCleanTicks = 0
        unhealthySince = nil

        if degradedSince == nil {
            degradedSince = snapshot.timestamp
        }

        let reason = snapshot.failureReason()
        status.failureReason = reason
        status.customHost = reason == .customHostDown ? snapshot.customResults.first(where: { !$0.success })?.customHost : nil

        let sustained = snapshot.timestamp.timeIntervalSince(degradedSince ?? snapshot.timestamp) >= evaluationWindow

        if sustained, let reason {
            transitionToOutage(snapshot: snapshot, reason: reason)
        } else {
            status.state = .degraded
        }
    }

    private func transitionToOutage(snapshot: ProbeSnapshot, reason: FailureReason?) {
        guard status.state != .outage else { return }

        status.state = .outage
        status.outageStartedAt = snapshot.timestamp

        let resolvedReason = reason ?? .ispOutage
        let detail = resolvedReason.message(host: status.customHost)
        let record = OutageRecord(
            startedAt: snapshot.timestamp,
            reason: resolvedReason,
            reasonDetail: detail,
            probeSummary: OutageRecord.probeSummary(from: snapshot)
        )
        currentOutageID = record.id
        currentOutageProbeSummary = record.probeSummary
        onOutageStarted?(record)
    }

    private func completeRecovery() {
        let endedAt = Date()
        let startedAt = status.outageStartedAt ?? endedAt
        let duration = endedAt.timeIntervalSince(startedAt)

        if let currentOutageID {
            let record = OutageRecord(
                id: currentOutageID,
                startedAt: startedAt,
                endedAt: endedAt,
                reason: status.failureReason ?? .ispOutage,
                reasonDetail: status.failureReason?.message(host: status.customHost) ?? "Recovered",
                probeSummary: currentOutageProbeSummary
            )
            onOutageEnded?(record, duration)
        }

        currentOutageID = nil
        currentOutageProbeSummary = nil
        status.state = .healthy
        status.outageStartedAt = nil
        status.failureReason = nil
        status.customHost = nil
        recoveryCleanTicks = 0
    }
}
