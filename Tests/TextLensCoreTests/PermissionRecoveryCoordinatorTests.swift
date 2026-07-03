import XCTest
@testable import TextLensCore

final class PermissionRecoveryCoordinatorTests: XCTestCase {
    func testStartsMonitoringOnceAfterPermissionBecomesTrusted() {
        var coordinator = PermissionRecoveryCoordinator()

        coordinator.recordPermissionPrompt()

        XCTAssertFalse(coordinator.observeTrustedState(false))
        XCTAssertTrue(coordinator.observeTrustedState(true))
        XCTAssertFalse(coordinator.observeTrustedState(true))
    }

    func testDoesNotStartMonitoringWithoutPriorPrompt() {
        var coordinator = PermissionRecoveryCoordinator()

        XCTAssertFalse(coordinator.observeTrustedState(true))
    }
}
