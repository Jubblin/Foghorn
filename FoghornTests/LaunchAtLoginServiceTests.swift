import XCTest
@testable import Foghorn

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    /// #101: an in-place update can drop the login-item registration. Losing it is
    /// not the user changing their mind, so it gets restored.
    func testRestoresWhenWantedButNotRegistered() {
        XCTAssertTrue(LaunchAtLoginService.shouldRestore(intent: true, status: .notRegistered))
    }

    func testLeavesRegistrationAloneWhenAlreadyEnabled() {
        XCTAssertFalse(LaunchAtLoginService.shouldRestore(intent: true, status: .enabled))
    }

    /// Only the user can clear `.requiresApproval`, in System Settings; re-registering
    /// would not move it along, and would fight whatever they chose there.
    func testDoesNotRestoreWhenAwaitingApproval() {
        XCTAssertFalse(LaunchAtLoginService.shouldRestore(intent: true, status: .requiresApproval))
    }

    func testDoesNotRegisterWhenTheUserWantsItOff() {
        for status in [LaunchAtLoginService.Status.notRegistered, .enabled, .requiresApproval] {
            XCTAssertFalse(
                LaunchAtLoginService.shouldRestore(intent: false, status: status),
                "Should not register when the preference is off (status: \(status))"
            )
        }
    }
}
