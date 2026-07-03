import CoreGraphics
import Foundation

public enum SelectionTriggerReason: Equatable, Sendable {
    case drag
    case doubleClick
    case shiftClick
    case keyboardSelection
}

public enum SelectionTriggerMouseKind: Sendable {
    case leftMouseDown
    case leftMouseDragged
    case leftMouseUp
}

public enum SelectionTriggerKeyCode {
    public static let a: UInt16 = 0
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
}

public struct SelectionTriggerModifiers: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let shift = SelectionTriggerModifiers(rawValue: 1 << 0)
    public static let command = SelectionTriggerModifiers(rawValue: 1 << 1)
    public static let option = SelectionTriggerModifiers(rawValue: 1 << 2)
    public static let control = SelectionTriggerModifiers(rawValue: 1 << 3)
}

public struct SelectionTriggerEvent: Sendable {
    public var kind: Kind
    public var timestamp: TimeInterval
    public var location: CGPoint
    public var keyCode: UInt16?
    public var modifiers: SelectionTriggerModifiers

    public enum Kind: Sendable {
        case mouse(SelectionTriggerMouseKind)
        case keyUp
    }

    public init(
        kind: Kind,
        timestamp: TimeInterval,
        location: CGPoint = .zero,
        keyCode: UInt16? = nil,
        modifiers: SelectionTriggerModifiers = []
    ) {
        self.kind = kind
        self.timestamp = timestamp
        self.location = location
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static func mouse(
        _ kind: SelectionTriggerMouseKind,
        at timestamp: TimeInterval,
        location: CGPoint,
        modifiers: SelectionTriggerModifiers = []
    ) -> SelectionTriggerEvent {
        SelectionTriggerEvent(
            kind: .mouse(kind),
            timestamp: timestamp,
            location: location,
            modifiers: modifiers
        )
    }

    public static func keyUp(
        keyCode: UInt16,
        modifiers: SelectionTriggerModifiers,
        at timestamp: TimeInterval = 0
    ) -> SelectionTriggerEvent {
        SelectionTriggerEvent(
            kind: .keyUp,
            timestamp: timestamp,
            keyCode: keyCode,
            modifiers: modifiers
        )
    }
}

public final class SelectionTriggerGate {
    public struct Configuration: Sendable {
        public var minimumDragDistance: CGFloat
        public var maximumDragDuration: TimeInterval
        public var doubleClickInterval: TimeInterval
        public var doubleClickMaximumDistance: CGFloat

        public init(
            minimumDragDistance: CGFloat = 8,
            maximumDragDuration: TimeInterval = 15,
            doubleClickInterval: TimeInterval = 0.5,
            doubleClickMaximumDistance: CGFloat = 3
        ) {
            self.minimumDragDistance = minimumDragDistance
            self.maximumDragDuration = maximumDragDuration
            self.doubleClickInterval = doubleClickInterval
            self.doubleClickMaximumDistance = doubleClickMaximumDistance
        }
    }

    private struct MouseRecord {
        var timestamp: TimeInterval
        var location: CGPoint
        var modifiers: SelectionTriggerModifiers
    }

    private let configuration: Configuration
    private var lastMouseDown: MouseRecord?
    private var lastMouseUp: MouseRecord?
    private var lastClickWasValid = false
    private var sawDragSinceMouseDown = false

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func reset() {
        lastMouseDown = nil
        lastMouseUp = nil
        lastClickWasValid = false
        sawDragSinceMouseDown = false
    }

    public func observe(_ event: SelectionTriggerEvent) -> SelectionTriggerReason? {
        switch event.kind {
        case let .mouse(kind):
            return observeMouse(kind, event: event)
        case .keyUp:
            return observeKeyUp(event)
        }
    }

    private func observeMouse(
        _ kind: SelectionTriggerMouseKind,
        event: SelectionTriggerEvent
    ) -> SelectionTriggerReason? {
        switch kind {
        case .leftMouseDown:
            lastMouseDown = MouseRecord(
                timestamp: event.timestamp,
                location: event.location,
                modifiers: event.modifiers
            )
            sawDragSinceMouseDown = false
            return nil

        case .leftMouseDragged:
            sawDragSinceMouseDown = true
            return nil

        case .leftMouseUp:
            return observeLeftMouseUp(event)
        }
    }

    private func observeLeftMouseUp(_ event: SelectionTriggerEvent) -> SelectionTriggerReason? {
        guard let mouseDown = lastMouseDown else {
            return nil
        }

        let pressDuration = event.timestamp - mouseDown.timestamp
        let dragDistance = distance(from: mouseDown.location, to: event.location)
        let currentClickIsValid = pressDuration <= configuration.doubleClickInterval
            && dragDistance <= configuration.doubleClickMaximumDistance

        defer {
            lastMouseUp = MouseRecord(
                timestamp: event.timestamp,
                location: event.location,
                modifiers: event.modifiers
            )
            lastClickWasValid = currentClickIsValid
            sawDragSinceMouseDown = false
        }

        guard pressDuration <= configuration.maximumDragDuration else {
            return nil
        }

        if sawDragSinceMouseDown, dragDistance >= configuration.minimumDragDistance {
            return .drag
        }

        if lastClickWasValid,
           let lastMouseUp,
           event.timestamp - lastMouseUp.timestamp <= configuration.doubleClickInterval,
           distance(from: lastMouseUp.location, to: event.location) <= configuration.doubleClickMaximumDistance {
            return .doubleClick
        }

        if isShiftOnly(event.modifiers) || isShiftOnly(mouseDown.modifiers) {
            return .shiftClick
        }

        return nil
    }

    private func observeKeyUp(_ event: SelectionTriggerEvent) -> SelectionTriggerReason? {
        guard let keyCode = event.keyCode else {
            return nil
        }

        if keyCode == SelectionTriggerKeyCode.a, isCommandOnly(event.modifiers) {
            return .keyboardSelection
        }

        if isArrowKey(keyCode),
           event.modifiers.contains(.shift),
           !event.modifiers.contains(.control) {
            return .keyboardSelection
        }

        return nil
    }

    private func isArrowKey(_ keyCode: UInt16) -> Bool {
        keyCode == SelectionTriggerKeyCode.leftArrow
            || keyCode == SelectionTriggerKeyCode.rightArrow
            || keyCode == SelectionTriggerKeyCode.downArrow
            || keyCode == SelectionTriggerKeyCode.upArrow
    }

    private func isCommandOnly(_ modifiers: SelectionTriggerModifiers) -> Bool {
        modifiers == .command
    }

    private func isShiftOnly(_ modifiers: SelectionTriggerModifiers) -> Bool {
        modifiers == .shift
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
}
