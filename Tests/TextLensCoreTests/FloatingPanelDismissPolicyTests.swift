import XCTest
@testable import TextLensCore

final class FloatingPanelDismissPolicyTests: XCTestCase {
    func testPointerDownDismissesFloatingPanel() {
        XCTAssertTrue(FloatingPanelDismissPolicy.shouldDismiss(for: .pointerDown))
    }

    func testEscapeKeyDismissesFloatingPanel() {
        XCTAssertTrue(FloatingPanelDismissPolicy.shouldDismiss(for: .keyDown(FloatingPanelKeyCode.escape)))
    }

    func testNonEscapeKeyDoesNotDismissFloatingPanel() {
        XCTAssertFalse(FloatingPanelDismissPolicy.shouldDismiss(for: .keyDown(36)))
    }
}
