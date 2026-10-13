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
        struct Case {
            let reason: FailureReason
            let snapshot: ProbeSnapshot
            let expected: [State]
            let detail: String
            init(_ reason: FailureReason, _ snapshot: ProbeSnapshot, _ expected: [State], _ detail: String) {
                self.reason = reason
                self.snapshot = snapshot
                self.expected = expected
                self.detail = detail
            }
        }
        let cases: [Case] = [
            Case(.noInterface, snapshot(path: false, gateway: false, dns: false, http: false),
             [.failed, .notReached, .notReached, .notReached], "no network"),
            Case(.routerUnreachable, snapshot(gateway: false, dns: false, http: false),
             [.passed, .failed, .notReached, .notReached], "no answer"),
            Case(.dnsFailure, snapshot(dns: false, http: false),
             [.passed, .passed, .failed, .notReached], "no answer"),
            Case(.ispOutage, snapshot(http: false),
             [.passed, .passed, .passed, .failed], "unreachable"),
            Case(.captivePortalLikely, snapshot(http: false, httpDetail: "redirect HTTP 302 — captive possible"),
             [.passed, .passed, .passed, .failed], "captive portal")
        ]
        for testCase in cases {
            let (reason, expected, detail) = (testCase.reason, testCase.expected, testCase.detail)
            let ladder = LayerLadder(status: status(.outage, testCase.snapshot, reason: reason))
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

@MainActor
final class OutageNotificationTextTests: XCTestCase {
    func testTitleNamesTheFailingLayer() {
        let cases: [(FailureReason, String)] = [
            (.noInterface, "No network interface is up"),
            (.routerUnreachable, "Router isn't responding"),
            (.dnsFailure, "DNS is failing"),
            (.ispOutage, "Internet connection is down"),
            (.captivePortalLikely, "Captive portal may be blocking access"),
            (.customHostDown, "Custom host down: vpn.example.com")
        ]
        for (reason, title) in cases {
            let text = AlertService.outageText(reason: reason, host: "vpn.example.com")
            XCTAssertEqual(text.title, title, "\(reason)")
            XCTAssertFalse(text.body.isEmpty, "\(reason)")
            XCTAssertNotEqual(text.body, text.title, "\(reason)")
        }
    }

    func testRecordedTitleWins() {
        XCTAssertEqual(AlertService.outageText(reason: .dnsFailure, title: "DNS is failing").title, "DNS is failing")
    }

    func testMissingReasonFallsBackToConnectionLost() {
        XCTAssertEqual(AlertService.outageText(reason: nil).title, "Connection lost")
    }
}
