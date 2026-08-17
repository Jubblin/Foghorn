import XCTest
import Network
@testable import Foghorn

private struct StubGatewayResolver: GatewayResolving {
    let gateway: String?

    func gatewayAddress() async -> String? {
        gateway
    }
}

private final class StubGatewayReachability: GatewayReachabilityChecking {
    let result: Bool
    private(set) var requestedHost: String?
    private(set) var requestedTimeoutMilliseconds: Int?

    init(result: Bool) {
        self.result = result
    }

    func isReachable(host: String, timeoutMilliseconds: Int) async -> Bool {
        requestedHost = host
        requestedTimeoutMilliseconds = timeoutMilliseconds
        return result
    }
}

final class GatewayProbeTests: XCTestCase {
    override func tearDown() {
        GatewayProbe.injectResolverForTesting(nil)
        GatewayProbe.injectReachabilityForTesting(nil)
        super.tearDown()
    }

    func testNoGatewaySkipsProbeAndStaysSuccessful() async {
        let reachability = StubGatewayReachability(result: false)
        GatewayProbe.injectResolverForTesting(StubGatewayResolver(gateway: nil))
        GatewayProbe.injectReachabilityForTesting(reachability)

        let result = await GatewayProbe.probe()

        XCTAssertEqual(result.kind, .gateway)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.detail, "no gateway (skipped)")
        XCTAssertNil(reachability.requestedHost)
    }

    func testReachableGatewayReportsGatewayAddress() async {
        let reachability = StubGatewayReachability(result: true)
        GatewayProbe.injectResolverForTesting(StubGatewayResolver(gateway: "192.168.1.1"))
        GatewayProbe.injectReachabilityForTesting(reachability)

        let result = await GatewayProbe.probe()

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.detail, "192.168.1.1")
        XCTAssertEqual(reachability.requestedHost, "192.168.1.1")
        XCTAssertEqual(reachability.requestedTimeoutMilliseconds, 2_000)
    }

    func testUnreachableGatewayReportsUnreachableAddress() async {
        GatewayProbe.injectResolverForTesting(StubGatewayResolver(gateway: "192.168.1.1"))
        GatewayProbe.injectReachabilityForTesting(StubGatewayReachability(result: false))

        let result = await GatewayProbe.probe()

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.detail, "unreachable 192.168.1.1")
    }

    func testPathGatewayMatchSkipsTCPReachability() async {
        let reachability = StubGatewayReachability(result: false)
        GatewayProbe.injectResolverForTesting(StubGatewayResolver(gateway: "192.168.1.1"))
        GatewayProbe.injectReachabilityForTesting(reachability)

        let result = await GatewayProbe.probe(pathGateways: ["192.168.1.1"])

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.detail, "192.168.1.1")
        XCTAssertNil(reachability.requestedHost)
    }

    func testPathGatewayUsedWhenResolverReturnsNil() async {
        let reachability = StubGatewayReachability(result: false)
        GatewayProbe.injectResolverForTesting(StubGatewayResolver(gateway: nil))
        GatewayProbe.injectReachabilityForTesting(reachability)

        let result = await GatewayProbe.probe(pathGateways: ["10.2.254.254"])

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.detail, "10.2.254.254")
        XCTAssertNil(reachability.requestedHost)
    }

    func testReachabilityEvaluatorTreatsReadyAsReachable() {
        XCTAssertEqual(GatewayReachabilityEvaluator.evaluate(state: .ready), true)
    }

    func testReachabilityEvaluatorTreatsConnectionRefusedAsReachable() {
        XCTAssertEqual(
            GatewayReachabilityEvaluator.evaluate(error: .posix(.ECONNREFUSED)),
            true
        )
        XCTAssertEqual(
            GatewayReachabilityEvaluator.evaluate(state: .failed(.posix(.ECONNREFUSED))),
            true
        )
        XCTAssertEqual(
            GatewayReachabilityEvaluator.evaluate(state: .waiting(.posix(.ECONNREFUSED))),
            true
        )
    }

    func testReachabilityEvaluatorTreatsHostUnreachableAsUnreachable() {
        XCTAssertEqual(
            GatewayReachabilityEvaluator.evaluate(error: .posix(.EHOSTUNREACH)),
            false
        )
        XCTAssertEqual(
            GatewayReachabilityEvaluator.evaluate(state: .failed(.posix(.ENETUNREACH))),
            false
        )
    }

    func testReachabilityEvaluatorKeepsInProgressStatesPending() {
        XCTAssertNil(GatewayReachabilityEvaluator.evaluate(state: .preparing))
        XCTAssertNil(GatewayReachabilityEvaluator.evaluate(state: .setup))
        XCTAssertNil(GatewayReachabilityEvaluator.evaluate(state: .cancelled))
    }
}
