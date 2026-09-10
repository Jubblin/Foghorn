import XCTest
@testable import Foghorn

final class LinkTransitionTests: XCTestCase {
    func testNoPreviousValueIsNeverATransition() {
        XCTAssertNil(LinkTransition.decide(previous: nil, current: true))
        XCTAssertNil(LinkTransition.decide(previous: nil, current: false))
    }

    func testUnchangedValueIsNotATransition() {
        XCTAssertNil(LinkTransition.decide(previous: true, current: true))
        XCTAssertNil(LinkTransition.decide(previous: false, current: false))
    }

    func testFlipToUnsatisfiedIsLost() {
        XCTAssertEqual(LinkTransition.decide(previous: true, current: false), .lost)
    }

    func testFlipToSatisfiedIsRestored() {
        XCTAssertEqual(LinkTransition.decide(previous: false, current: true), .restored)
    }
}

final class MonitoringLifecycleTrackerTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "MonitoringLifecycleTrackerTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFreshInstallDoesNotShowPaused() {
        XCTAssertFalse(MonitoringLifecycleTracker.consumePausedFlag(in: defaults))
    }

    func testBackgroundingThenReconsumingShowsPaused() {
        MonitoringLifecycleTracker.markBackgrounded(in: defaults)
        XCTAssertTrue(MonitoringLifecycleTracker.consumePausedFlag(in: defaults))
    }

    func testConsumingClearsTheFlag() {
        MonitoringLifecycleTracker.markBackgrounded(in: defaults)
        _ = MonitoringLifecycleTracker.consumePausedFlag(in: defaults)
        XCTAssertFalse(MonitoringLifecycleTracker.consumePausedFlag(in: defaults))
    }

    func testConfirmedRunningClearsTheUncertainFlag() {
        MonitoringLifecycleTracker.markBackgrounded(in: defaults)
        MonitoringLifecycleTracker.markConfirmedRunning(in: defaults)
        XCTAssertFalse(MonitoringLifecycleTracker.consumePausedFlag(in: defaults))
    }
}
