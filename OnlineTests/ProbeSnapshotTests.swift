import XCTest
@testable import Online

@MainActor
final class ProbeSnapshotTests: XCTestCase {
    func testFullyHealthyRequiresAllProbes() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: true),
            .init(kind: .httpSecondary, success: false),
            .init(kind: .custom, success: true, customHost: "vpn.example.com")
        ])

        XCTAssertTrue(snapshot.isFullyHealthy)
        XCTAssertNil(snapshot.failureReason())
    }

    func testMissingGatewayProbeTreatedAsFailure() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: true)
        ])

        XCTAssertFalse(snapshot.isFullyHealthy)
        XCTAssertFalse(snapshot.gatewayOK)
    }

    func testRouterUnreachableAttribution() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: false, detail: "unreachable"),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: false),
            .init(kind: .httpSecondary, success: false)
        ])

        XCTAssertEqual(snapshot.failureReason(), .routerUnreachable)
    }

    func testCaptivePortalAttribution() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: false, detail: "redirect HTTP 302 — captive possible"),
            .init(kind: .httpSecondary, success: false)
        ])

        XCTAssertEqual(snapshot.failureReason(), .captivePortalLikely)
    }

    func testCustomHostDownAttribution() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true),
            .init(kind: .gateway, success: true),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: true),
            .init(kind: .custom, success: false, customHost: "vpn.corp")
        ])

        XCTAssertEqual(snapshot.failureReason(), .customHostDown)
    }

    func testProbeRowsPreferPathAndGatewayDetail() {
        let snapshot = ProbeSnapshot(timestamp: Date(), results: [
            .init(kind: .path, success: true, detail: "via en4/wired"),
            .init(kind: .gateway, success: true, detail: "10.2.254.254"),
            .init(kind: .dns, success: true),
            .init(kind: .httpPrimary, success: true)
        ])
        var status = ConnectivityStatus.initial
        status.lastSnapshot = snapshot

        let rows = Dictionary(uniqueKeysWithValues: status.probeRows.map { ($0.label, $0.detail) })
        XCTAssertEqual(rows["PATH"], "via en4/wired")
        XCTAssertEqual(rows["GATEWAY"], "10.2.254.254")
        XCTAssertEqual(rows["DNS"], "ok")
    }
}
