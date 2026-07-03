public enum SelectionCapturePolicy: Equatable, Sendable {
    case allowCopyFallback
    case requireExposedSelection

    public static func policy(for triggerReason: SelectionTriggerReason) -> SelectionCapturePolicy {
        switch triggerReason {
        case .doubleClick:
            .requireExposedSelection
        case .drag, .shiftClick, .keyboardSelection:
            .allowCopyFallback
        }
    }

    public var allowsCopyFallback: Bool {
        self == .allowCopyFallback
    }
}
