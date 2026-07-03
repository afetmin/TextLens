import Foundation
import XCTest
@testable import TextLensCore

final class SelectionEventGateTests: XCTestCase {
    func testRejectsBlankAndWhitespaceOnlyText() {
        let gate = SelectionEventGate(debounceInterval: 0.5, maximumTextLength: 100)

        XCTAssertNil(gate.snapshot(for: "   \n\t  ", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date()))
    }

    func testTrimsTextBeforeReturningSnapshot() throws {
        let gate = SelectionEventGate(debounceInterval: 0.5, maximumTextLength: 100)

        let snapshot = try XCTUnwrap(gate.snapshot(for: "  hello world \n", sourceBundleID: "com.apple.TextEdit", anchor: CGPoint(x: 10, y: 20), at: Date(timeIntervalSince1970: 10)))

        XCTAssertEqual(snapshot.text, "hello world")
        XCTAssertEqual(snapshot.sourceBundleID, "com.apple.TextEdit")
        XCTAssertEqual(snapshot.anchorPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(snapshot.capturedAt, Date(timeIntervalSince1970: 10))
    }

    func testSuppressesSameSelectionInsideDebounceWindow() {
        let gate = SelectionEventGate(debounceInterval: 0.5, maximumTextLength: 100)
        let first = gate.snapshot(for: "hello", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date(timeIntervalSince1970: 1))
        let second = gate.snapshot(for: "hello", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date(timeIntervalSince1970: 1.2))

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testAllowsSameSelectionAfterDebounceWindow() {
        let gate = SelectionEventGate(debounceInterval: 0.5, maximumTextLength: 100)
        _ = gate.snapshot(for: "hello", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date(timeIntervalSince1970: 1))

        let snapshot = gate.snapshot(for: "hello", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(snapshot?.text, "hello")
    }

    func testResetAllowsSameSelectionImmediately() {
        let gate = SelectionEventGate(debounceInterval: 0.5, maximumTextLength: 100)
        _ = gate.snapshot(for: "hello", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date(timeIntervalSince1970: 1))

        gate.reset()

        let snapshot = gate.snapshot(for: "hello", sourceBundleID: "com.apple.TextEdit", anchor: .zero, at: Date(timeIntervalSince1970: 1.1))

        XCTAssertEqual(snapshot?.text, "hello")
    }

    func testRejectsTextLongerThanMaximum() {
        let gate = SelectionEventGate(debounceInterval: 0.5, maximumTextLength: 5)

        XCTAssertNil(gate.snapshot(for: "123456", sourceBundleID: nil, anchor: .zero, at: Date()))
    }
}
