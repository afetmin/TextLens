import XCTest
@testable import TextLensCore

final class MenuBarStatusPolicyTests: XCTestCase {
    func testHidesUnavailableSelectionStatus() {
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "当前应用未暴露选中文本"))
    }

    func testHidesNoFocusedElementStatus() {
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "当前应用没有可读取的焦点控件"))
    }

    func testHidesRoutineReadinessStatus() {
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "已准备读取选区"))
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "划词自动弹出已开启"))
    }

    func testHidesPermissionStatusBecauseMenuShowsAnAction() {
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "需要辅助功能权限"))
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "请在系统设置中授权"))
        XCTAssertNil(MenuBarStatusPolicy.displayMessage(for: "仍未检测到辅助功能权限"))
    }

    func testTrimsDisplayedStatus() {
        XCTAssertEqual(MenuBarStatusPolicy.displayMessage(for: "  正在处理请求  "), "正在处理请求")
    }
}
