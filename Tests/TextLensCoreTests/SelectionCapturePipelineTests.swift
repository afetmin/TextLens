import CoreGraphics
import XCTest
@testable import TextLensCore

final class SelectionCapturePipelineTests: XCTestCase {
    func testDragEventProducesCaptureRequestWithCopyFallbackPolicy() {
        let pipeline = makePipeline()

        XCTAssertNil(pipeline.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20))))
        XCTAssertNil(pipeline.observe(.mouse(.leftMouseDragged, at: 1.1, location: CGPoint(x: 30, y: 20))))
        let request = pipeline.observe(.mouse(.leftMouseUp, at: 1.2, location: CGPoint(x: 36, y: 20)))

        XCTAssertEqual(
            request,
            SelectionCaptureRequest(
                anchor: CGPoint(x: 36, y: 20),
                policy: .allowCopyFallback
            )
        )
    }

    func testDoubleClickProducesCaptureRequestRequiringExposedSelection() {
        let pipeline = makePipeline()

        _ = pipeline.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20)))
        _ = pipeline.observe(.mouse(.leftMouseUp, at: 1.05, location: CGPoint(x: 20, y: 20)))
        _ = pipeline.observe(.mouse(.leftMouseDown, at: 1.2, location: CGPoint(x: 21, y: 20)))
        let request = pipeline.observe(.mouse(.leftMouseUp, at: 1.25, location: CGPoint(x: 21, y: 20)))

        XCTAssertEqual(
            request,
            SelectionCaptureRequest(
                anchor: CGPoint(x: 21, y: 20),
                policy: .requireExposedSelection
            )
        )
    }

    func testKeyboardSelectionUsesCurrentPointerAnchorFromEvent() {
        let pipeline = makePipeline()

        let request = pipeline.observe(
            SelectionTriggerEvent(
                kind: .keyUp,
                timestamp: 2.0,
                location: CGPoint(x: 320, y: 180),
                keyCode: SelectionTriggerKeyCode.rightArrow,
                modifiers: .shift
            )
        )

        XCTAssertEqual(
            request,
            SelectionCaptureRequest(
                anchor: CGPoint(x: 320, y: 180),
                policy: .allowCopyFallback
            )
        )
    }

    func testRawSelectionBecomesTrimmedSnapshot() throws {
        let pipeline = makePipeline()
        let date = Date(timeIntervalSince1970: 100)

        let snapshot = try XCTUnwrap(
            pipeline.snapshot(
                for: RawSelection(text: "  hello \n", sourceBundleID: "com.example.editor"),
                anchor: CGPoint(x: 8, y: 9),
                at: date
            )
        )

        XCTAssertEqual(snapshot.text, "hello")
        XCTAssertEqual(snapshot.sourceBundleID, "com.example.editor")
        XCTAssertEqual(snapshot.anchorPoint, CGPoint(x: 8, y: 9))
        XCTAssertEqual(snapshot.capturedAt, date)
    }

    func testDuplicateSnapshotIsDebouncedUntilReset() {
        let pipeline = makePipeline()
        let rawSelection = RawSelection(text: "hello", sourceBundleID: "com.example.editor")

        let first = pipeline.snapshot(
            for: rawSelection,
            anchor: .zero,
            at: Date(timeIntervalSince1970: 1.0)
        )
        let duplicate = pipeline.snapshot(
            for: rawSelection,
            anchor: .zero,
            at: Date(timeIntervalSince1970: 1.1)
        )
        pipeline.reset()
        let afterReset = pipeline.snapshot(
            for: rawSelection,
            anchor: .zero,
            at: Date(timeIntervalSince1970: 1.2)
        )

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)
        XCTAssertNotNil(afterReset)
    }

    private func makePipeline() -> SelectionCapturePipeline {
        SelectionCapturePipeline(
            eventGate: SelectionEventGate(
                debounceInterval: 0.45,
                maximumTextLength: 4_000
            )
        )
    }
}
