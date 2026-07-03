import XCTest
@testable import TextLensCore

final class SelectionCapturePolicyTests: XCTestCase {
    func testDoubleClickRequiresExposedSelectionInsteadOfCopyFallback() {
        XCTAssertEqual(
            SelectionCapturePolicy.policy(for: .doubleClick),
            .requireExposedSelection
        )
    }

    func testOtherSelectionTriggersCanUseCopyFallback() {
        XCTAssertEqual(SelectionCapturePolicy.policy(for: .drag), .allowCopyFallback)
        XCTAssertEqual(SelectionCapturePolicy.policy(for: .shiftClick), .allowCopyFallback)
        XCTAssertEqual(SelectionCapturePolicy.policy(for: .keyboardSelection), .allowCopyFallback)
    }
}
