import XCTest
@testable import Foghorn

final class OutageRecordTests: XCTestCase {
    // MARK: - Popover recency (#105)

    private func record(endedAt: Date?) -> OutageRecord {
        OutageRecord(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: endedAt,
            reason: .routerUnreachable,
            reasonDetail: "Router unreachable",
            probeSummary: nil
        )
    }

    func testOngoingOutageNeverExpires() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(record(endedAt: nil).isRecent(within: 60, now: now))
    }

    func testRecoveredOutageStaysWhileRecent() {
        let endedAt = Date(timeIntervalSince1970: 5_000)
        let now = endedAt.addingTimeInterval(59)
        XCTAssertTrue(record(endedAt: endedAt).isRecent(within: 60, now: now))
    }

    func testRecoveredOutageExpiresAfterTheWindow() {
        let endedAt = Date(timeIntervalSince1970: 5_000)
        let now = endedAt.addingTimeInterval(61)
        XCTAssertFalse(record(endedAt: endedAt).isRecent(within: 60, now: now))
    }

    /// Measured from endedAt, so a long outage that just recovered is still shown —
    /// measuring from startedAt would expire it the moment it ended.
    func testLongOutageThatJustRecoveredIsStillRecent() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = startedAt.addingTimeInterval(6 * 60 * 60)
        let subject = OutageRecord(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            reason: .routerUnreachable,
            reasonDetail: "Router unreachable",
            probeSummary: nil
        )
        XCTAssertTrue(subject.isRecent(within: 60 * 60, now: endedAt.addingTimeInterval(30)))
    }

    func testProbeSummaryFormatsResults() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: false),
            .init(kind: .dns, success: true)
        ])

        let summary = OutageRecord.probeSummary(from: snapshot)

        XCTAssertTrue(summary.contains("path:ok"))
        XCTAssertTrue(summary.contains("gateway:fail"))
        XCTAssertTrue(summary.contains("dns:ok"))
    }

    func testProbeSummaryIncludesPathInterfaceDetail() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true, detail: "via en4/wired"),
            .init(kind: .gateway, success: true, detail: "10.2.254.254")
        ])

        let summary = OutageRecord.probeSummary(from: snapshot)

        XCTAssertTrue(summary.contains("path:ok(via en4/wired)"))
        XCTAssertTrue(summary.contains("gateway:ok"))
        XCTAssertFalse(summary.contains("gateway:ok(10.2.254.254)"))
    }

    func testDecodesLegacyRecordWithoutProbeSummary() throws {
        let json = """
        [{
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "startedAt": "2026-07-01T12:00:00Z",
            "endedAt": "2026-07-01T12:01:00Z",
            "reason": "ispOutage",
            "reasonDetail": "ISP / internet outage"
        }]
        """
        let data = Data(json.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([OutageRecord].self, from: data)

        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records[0].probeSummary)
    }
}
