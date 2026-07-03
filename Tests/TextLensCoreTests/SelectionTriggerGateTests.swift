import CoreGraphics
import XCTest
@testable import TextLensCore

final class SelectionTriggerGateTests: XCTestCase {
    func testPlainClickDoesNotTriggerSelectionCapture() {
        let gate = SelectionTriggerGate()

        XCTAssertNil(gate.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20))))
        XCTAssertNil(gate.observe(.mouse(.leftMouseUp, at: 1.1, location: CGPoint(x: 21, y: 21))))
    }

    func testDragPastThresholdTriggersSelectionCaptureOnMouseUp() {
        let gate = SelectionTriggerGate()

        _ = gate.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20)))
        _ = gate.observe(.mouse(.leftMouseDragged, at: 1.1, location: CGPoint(x: 25, y: 20)))
        let reason = gate.observe(.mouse(.leftMouseUp, at: 1.2, location: CGPoint(x: 32, y: 20)))

        XCTAssertEqual(reason, .drag)
    }

    func testTinyMouseMovementDoesNotTriggerDragSelectionCapture() {
        let gate = SelectionTriggerGate()

        _ = gate.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20)))
        _ = gate.observe(.mouse(.leftMouseDragged, at: 1.1, location: CGPoint(x: 22, y: 20)))
        let reason = gate.observe(.mouse(.leftMouseUp, at: 1.2, location: CGPoint(x: 23, y: 20)))

        XCTAssertNil(reason)
    }

    func testDoubleClickWithinTimeAndDistanceTriggersSelectionCapture() {
        let gate = SelectionTriggerGate()

        _ = gate.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20)))
        _ = gate.observe(.mouse(.leftMouseUp, at: 1.05, location: CGPoint(x: 20, y: 20)))
        _ = gate.observe(.mouse(.leftMouseDown, at: 1.2, location: CGPoint(x: 21, y: 20)))
        let reason = gate.observe(.mouse(.leftMouseUp, at: 1.25, location: CGPoint(x: 21, y: 20)))

        XCTAssertEqual(reason, .doubleClick)
    }

    func testSlowSecondClickDoesNotTriggerDoubleClickCapture() {
        let gate = SelectionTriggerGate()

        _ = gate.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20)))
        _ = gate.observe(.mouse(.leftMouseUp, at: 1.05, location: CGPoint(x: 20, y: 20)))
        _ = gate.observe(.mouse(.leftMouseDown, at: 1.8, location: CGPoint(x: 20, y: 20)))
        let reason = gate.observe(.mouse(.leftMouseUp, at: 1.85, location: CGPoint(x: 20, y: 20)))

        XCTAssertNil(reason)
    }

    func testShiftClickTriggersSelectionCapture() {
        let gate = SelectionTriggerGate()

        _ = gate.observe(.mouse(.leftMouseDown, at: 1.0, location: CGPoint(x: 20, y: 20), modifiers: .shift))
        let reason = gate.observe(.mouse(.leftMouseUp, at: 1.1, location: CGPoint(x: 20, y: 20), modifiers: .shift))

        XCTAssertEqual(reason, .shiftClick)
    }

    func testShiftArrowKeyTriggersSelectionCapture() {
        let gate = SelectionTriggerGate()

        let reason = gate.observe(.keyUp(keyCode: SelectionTriggerKeyCode.rightArrow, modifiers: .shift))

        XCTAssertEqual(reason, .keyboardSelection)
    }

    func testCommandShiftArrowKeyTriggersSelectionCapture() {
        let gate = SelectionTriggerGate()

        let reason = gate.observe(.keyUp(
            keyCode: SelectionTriggerKeyCode.rightArrow,
            modifiers: [.command, .shift]
        ))

        XCTAssertEqual(reason, .keyboardSelection)
    }

    func testCommandATriggersSelectionCapture() {
        let gate = SelectionTriggerGate()

        let reason = gate.observe(.keyUp(keyCode: SelectionTriggerKeyCode.a, modifiers: .command))

        XCTAssertEqual(reason, .keyboardSelection)
    }

    func testShiftLetterKeyDoesNotTriggerSelectionCapture() {
        let gate = SelectionTriggerGate()

        let reason = gate.observe(.keyUp(keyCode: SelectionTriggerKeyCode.a, modifiers: .shift))

        XCTAssertNil(reason)
    }
}
