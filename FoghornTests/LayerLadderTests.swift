import XCTest
#if os(iOS)
@testable import FoghorniOS
#else
@testable import Foghorn
#endif

@MainActor
final class LayerLadderTests: XCTestCase {
    private typealias State = LayerLadder.RungState

    private func snapshot(
        path: Bool = true,
        gateway: Bool = true,
        gatewayDetail: String? = "192.168.1.1",
        dns: Bool = true,
        http: Bool = true,
        httpDetail: String? = nil,
        custom: Bool? = nil
    ) -> ProbeSnapshot {
        var results: [SingleProbeResult] = [
            .init(kind: .path, success: path, detail: "via en0/wifi"),
            .init(kind: .gateway, success: gateway, detail: gatewayDetail),
            .init(kind: .dns, success: dns),
            .init(kind: .httpPrimary, success: http, detail: httpDetail),
            .init(kind: .httpSecondary, success: http)
        ]
        if let custom {
            results.append(.init(kind: .custom, success: custom, customHost: "vpn.example.com"))
        }
        return ProbeSnapshot(timestamp: Date(), results: results)
    }

    private func status(
        _ state: ConnectivityState,
        _ snapshot: ProbeSnapshot?,
        reason: FailureReason? = nil,
        host: String? = nil
    ) -> ConnectivityStatus {
        ConnectivityStatus(
            state: state,
            lastSnapshot: snapshot,
            failureReason: reason,
            customHost: host,
            lastCheck: Date(),
            outageStartedAt: nil,
            healthySince: nil
        )
    }

    private func states(_ ladder: LayerLadder) -> [State] {
        ladder.rungs.map(\.state)
    }

    func testRungsAreAlwaysPhoneRouterDNSInternet() {
        let ladder = LayerLadder(status: status(.healthy, snapshot()))
        XCTAssertEqual(ladder.rungs.map(\.layer), [.phone, .router, .dns, .internet])
    }

    func testHealthyPassesEveryRungAndLightsNothing() {
        let ladder = LayerLadder(status: status(.healthy, snapshot()))
        XCTAssertEqual(states(ladder), [.passed, .passed, .passed, .passed])
        XCTAssertNil(ladder.litLayer)
        XCTAssertEqual(ladder.rungs[0].detail, "via en0/wifi")
        XCTAssertEqual(ladder.rungs[1].detail, "192.168.1.1")
    }

    func testEachFailureLightsItsLayerAndLeavesLaterRungsUnreached() {
        let cases: [(FailureReason, ProbeSnapshot, [State], String)] = [
            (.noInterface, snapshot(path: false, gateway: false, dns: false, http: false),
             [.failed, .notReached, .notReached, .notReached], "no network"),
            (.routerUnreachable, snapshot(gateway: false, dns: false, http: false),
             [.passed, .failed, .notReached, .notReached], "no answer"),
            (.dnsFailure, snapshot(dns: false, http: false),
             [.passed, .passed, .failed, .notReached], "no answer"),
            (.ispOutage, snapshot(http: false),
             [.passed, .passed, .passed, .failed], "unreachable"),
            (.captivePortalLikely, snapshot(http: false, httpDetail: "redirect HTTP 302 — captive possible"),
             [.passed, .passed, .passed, .failed], "captive portal")
        ]
        for (reason, snap, expected, detail) in cases {
            let ladder = LayerLadder(status: status(.outage, snap, reason: reason))
            XCTAssertEqual(states(ladder), expected, "\(reason)")
            XCTAssertEqual(ladder.litLayer, LayerLadder.layer(for: reason), "\(reason)")
            XCTAssertEqual(ladder.rungs.first { $0.layer == ladder.litLayer }?.detail, detail, "\(reason)")
        }
    }

    func testDegradedStateUsesDegradedTone() {
        let ladder = LayerLadder(status: status(.degraded, snapshot(custom: false), reason: .customHostDown, host: "vpn.example.com"))
        XCTAssertEqual(states(ladder), [.passed, .passed, .passed, .degraded])
        XCTAssertEqual(ladder.rungs[3].detail, "vpn.example.com down")
    }

    func testReasonFallsBackToSnapshotAttribution() {
        let ladder = LayerLadder(status: status(.outage, snapshot(dns: false, http: false)))
        XCTAssertEqual(ladder.litLayer, .dns)
    }

    func testSkippedGatewayIsNotChecked() {
        let skipped = snapshot(gatewayDetail: "no gateway (skipped)")
        XCTAssertEqual(states(LayerLadder(status: status(.healthy, skipped))), [.passed, .notChecked, .passed, .passed])

        let failingDNS = snapshot(gatewayDetail: "no gateway (skipped)", dns: false, http: false)
        let ladder = LayerLadder(status: status(.outage, failingDNS, reason: .dnsFailure))
        XCTAssertEqual(states(ladder), [.passed, .notChecked, .failed, .notReached])
        XCTAssertEqual(ladder.rungs[1].detail, "not checked")
    }

    func testNoSnapshotYetIsWaiting() {
        let ladder = LayerLadder(status: status(.healthy, nil))
        XCTAssertEqual(states(ladder), [.waiting, .waiting, .waiting, .waiting])
        XCTAssertNil(ladder.litLayer)
    }

    func testCheckingOverridesEverything() {
        let ladder = LayerLadder(status: status(.outage, snapshot(dns: false), reason: .dnsFailure), isChecking: true)
        XCTAssertEqual(states(ladder), [.checking, .checking, .checking, .checking])
        XCTAssertNil(ladder.litLayer)
    }

    func testRecoveringWithCleanSnapshotLightsNothing() {
        let ladder = LayerLadder(status: status(.recovering, snapshot()))
        XCTAssertEqual(states(ladder), [.passed, .passed, .passed, .passed])
    }
}
