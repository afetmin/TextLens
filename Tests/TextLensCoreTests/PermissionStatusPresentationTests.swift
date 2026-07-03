import XCTest
@testable import TextLensCore

final class PermissionStatusPresentationTests: XCTestCase {
    func testGrantedAccessibilityPresentation() {
        let presentation = PermissionStatusPresentation.accessibility(isTrusted: true)

        XCTAssertEqual(presentation.title, "辅助功能")
        XCTAssertEqual(presentation.status, "已授权")
        XCTAssertEqual(presentation.systemImage, "checkmark.seal.fill")
        XCTAssertEqual(presentation.actionTitle, "已完成")
        XCTAssertTrue(presentation.isActionDisabled)
    }

    func testMissingAccessibilityPresentation() {
        let presentation = PermissionStatusPresentation.accessibility(isTrusted: false)

        XCTAssertEqual(presentation.title, "辅助功能")
        XCTAssertEqual(presentation.status, "未授权")
        XCTAssertEqual(presentation.systemImage, "arrow.right.circle.fill")
        XCTAssertEqual(presentation.actionTitle, "授权")
        XCTAssertFalse(presentation.isActionDisabled)
    }
}
