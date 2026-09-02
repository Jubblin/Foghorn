import XCTest
@testable import Foghorn

@MainActor
final class ConnectivityStateMachineTests: XCTestCase {
    private func unhealthySnapshot(at date: Date = Date()) -> ProbeSnapshot {
        ProbeSnapshot(timestamp: date, results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: false),
            .init(kind: .httpSecondary, success: false)
        ])
    }

    private func healthySnapshot(at date: Date = Date()) -> ProbeSnapshot {
        ProbeSnapshot(timestamp: date, results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: true),
            .init(kind: .httpSecondary, success: true)
        ])
    }

    // MARK: - Healthy clock (#106)

    func testHealthySinceStartsOnTheFirstHealthyTick() {
        let machine = ConnectivityStateMachine()
        let first = Date(timeIntervalSince1970: 1_000)
        machine.process(snapshot: healthySnapshot(at: first))

        XCTAssertEqual(machine.status.healthySince, first)
    }

    func testHealthySinceKeepsTheOriginalEntryTime() {
        let machine = ConnectivityStateMachine()
        let first = Date(timeIntervalSince1970: 1_000)
        machine.process(snapshot: healthySnapshot(at: first))
        machine.process(snapshot: healthySnapshot(at: first.addingTimeInterval(120)))

        XCTAssertEqual(machine.status.healthySince, first, "the clock should not restart each tick")
    }

    func testHealthySinceClearsWhenSomethingFails() {
        let machine = ConnectivityStateMachine()
        machine.process(snapshot: healthySnapshot())
        XCTAssertNotNil(machine.status.healthySince)

        machine.process(snapshot: unhealthySnapshot())

        XCTAssertNil(machine.status.healthySince, "a failure ends the quiet period")
    }

    // MARK: - Probe row visibility (#106)

    func testProbeRowsShowWhileHealthyIsRecent() {
        var status = ConnectivityStatus.initial
        let since = Date(timeIntervalSince1970: 5_000)
        status.state = .healthy
        status.healthySince = since

        XCTAssertTrue(status.showsProbeEvidence(quietAfter: 60, now: since.addingTimeInterval(59)))
    }

    func testProbeRowsHideOnceHealthyHasSettled() {
        var status = ConnectivityStatus.initial
        let since = Date(timeIntervalSince1970: 5_000)
        status.state = .healthy
        status.healthySince = since

        XCTAssertFalse(status.showsProbeEvidence(quietAfter: 60, now: since.addingTimeInterval(61)))
    }

    /// The rows are the most useful thing in the app when something is wrong, so no
    /// unhealthy state ever hides them however long it lasts.
    func testProbeRowsAlwaysShowWhenNotHealthy() {
        let since = Date(timeIntervalSince1970: 5_000)
        for state in [ConnectivityState.degraded, .outage, .recovering] {
            var status = ConnectivityStatus.initial
            status.state = state
            status.healthySince = nil

            XCTAssertTrue(
                status.showsProbeEvidence(quietAfter: 60, now: since.addingTimeInterval(6_000)),
                "\(state) should keep the probe rows"
            )
        }
    }

    func testProbeRowsShowBeforeTheHealthyClockStarts() {
        let status = ConnectivityStatus.initial

        XCTAssertTrue(status.showsProbeEvidence(quietAfter: 60), "no anchor yet, so nothing to hide behind")
    }

    func testRapidCriticalFailuresTriggerOutage() {
        let machine = ConnectivityStateMachine()
        var outageCount = 0
        machine.onOutageStarted = { _ in outageCount += 1 }

        for _ in 0 ..< 3 {
            machine.process(snapshot: unhealthySnapshot())
        }

        XCTAssertEqual(machine.status.state, .outage)
        XCTAssertEqual(outageCount, 1)
    }

    func testRecoveryRequiresTwoCleanTicks() {
        let machine = ConnectivityStateMachine()
        for _ in 0 ..< 3 {
            machine.process(snapshot: unhealthySnapshot())
        }
        XCTAssertEqual(machine.status.state, .outage)

        var restored = false
        machine.onOutageEnded = { _, _ in restored = true }

        let healthy = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: true),
            .init(kind: .httpSecondary, success: true)
        ])

        machine.process(snapshot: healthy)
        XCTAssertEqual(machine.status.state, .recovering)
        XCTAssertFalse(restored)

        machine.process(snapshot: healthy)
        XCTAssertEqual(machine.status.state, .healthy)
        XCTAssertTrue(restored)
    }

    func testWakeGraceSuppressesStateTransitions() {
        let machine = ConnectivityStateMachine()
        machine.setWakeGrace(seconds: 60)

        for _ in 0 ..< 5 {
            machine.process(snapshot: unhealthySnapshot())
        }

        XCTAssertEqual(machine.status.state, .healthy)
    }
}
