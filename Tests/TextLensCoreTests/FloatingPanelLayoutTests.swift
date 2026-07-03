import CoreGraphics
import XCTest
@testable import TextLensCore

final class FloatingPanelLayoutTests: XCTestCase {
    private let visibleFrame = CGRect(x: 0, y: 0, width: 500, height: 400)

    func testFallsBackAboveWhenPreferredBelowDoesNotFitNearBottom() {
        let result = result(
            preferredSize: CGSize(width: 160, height: 120),
            anchor: CGPoint(x: 200, y: 30),
            preferredPlacement: .belowAnchor
        )

        XCTAssertEqual(result.placement, .aboveAnchor)
        XCTAssertEqual(result.frame, CGRect(x: 212, y: 38, width: 160, height: 120))
    }

    func testUsesPreferredBelowWhenThereIsRoomNearTop() {
        let result = result(
            preferredSize: CGSize(width: 160, height: 120),
            anchor: CGPoint(x: 200, y: 360),
            preferredPlacement: .belowAnchor
        )

        XCTAssertEqual(result.placement, .belowAnchor)
        XCTAssertEqual(result.frame, CGRect(x: 212, y: 232, width: 160, height: 120))
    }

    func testLimitsHeightToTheChosenSideAvailableSpace() {
        let result = result(
            preferredSize: CGSize(width: 180, height: 500),
            anchor: CGPoint(x: 200, y: 150),
            preferredPlacement: .belowAnchor
        )

        XCTAssertEqual(result.placement, .aboveAnchor)
        XCTAssertEqual(result.frame, CGRect(x: 212, y: 158, width: 180, height: 232))
        XCTAssertLessThanOrEqual(result.frame.maxY, visibleFrame.maxY - 10)
    }

    func testClampsHorizontallyInsideVisibleFrame() {
        let result = result(
            preferredSize: CGSize(width: 160, height: 120),
            anchor: CGPoint(x: 470, y: 200),
            preferredPlacement: .belowAnchor
        )

        XCTAssertEqual(result.frame.minX, 330)
        XCTAssertEqual(result.frame.maxX, 490)
    }

    private func result(
        preferredSize: CGSize,
        anchor: CGPoint,
        preferredPlacement: FloatingPanelPlacement
    ) -> FloatingPanelLayoutResult {
        FloatingPanelLayoutRules(
            screenInset: 10,
            anchorGap: 8,
            horizontalOffset: 12,
            preferredPlacement: preferredPlacement
        )
        .layout(
            preferredSize: preferredSize,
            near: anchor,
            in: visibleFrame
        )
    }
}
