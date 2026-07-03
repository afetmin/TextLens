import XCTest
@testable import TextLensCore

final class PermissionAuthorizationPlanTests: XCTestCase {
    func testAccessibilityAuthorizationUsesPermissionFlowWithoutNativePrompt() {
        let plan = PermissionAuthorizationPlan.accessibility

        XCTAssertTrue(plan.opensGuidedSettings)
        XCTAssertFalse(plan.requestsNativePrompt)
        XCTAssertTrue(plan.startsRecoveryPolling)
    }
}
