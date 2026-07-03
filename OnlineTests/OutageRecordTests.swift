import XCTest
@testable import Online

final class OutageRecordTests: XCTestCase {
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
