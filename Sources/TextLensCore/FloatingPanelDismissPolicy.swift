public enum FloatingPanelDismissEvent: Equatable, Sendable {
    case pointerDown
    case keyDown(UInt16)
}

public enum FloatingPanelKeyCode {
    public static let escape: UInt16 = 53
}

public enum FloatingPanelDismissPolicy {
    public static func shouldDismiss(for event: FloatingPanelDismissEvent) -> Bool {
        switch event {
        case .pointerDown:
            true
        case .keyDown(let keyCode):
            keyCode == FloatingPanelKeyCode.escape
        }
    }
}
