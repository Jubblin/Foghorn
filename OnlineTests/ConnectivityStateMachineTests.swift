import XCTest
@testable import Online

@MainActor
final class ConnectivityStateMachineTests: XCTestCase {
    private func unhealthySnapshot(at date: Date = Date()) -> ProbeSnapshot {
        ProbeSnapshot(timestamp: date, results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: false),
            .init(kind: .httpSecondary, success: false),
        ])
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
            .init(kind: .httpSecondary, success: true),
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
