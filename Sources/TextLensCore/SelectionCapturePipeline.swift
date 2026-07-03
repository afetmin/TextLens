import CoreGraphics
import Foundation

public struct RawSelection: Equatable, Sendable {
    public var text: String
    public var sourceBundleID: String?

    public init(text: String, sourceBundleID: String?) {
        self.text = text
        self.sourceBundleID = sourceBundleID
    }
}

public struct SelectionCaptureRequest: Equatable, Sendable {
    public var anchor: CGPoint
    public var policy: SelectionCapturePolicy

    public init(anchor: CGPoint, policy: SelectionCapturePolicy) {
        self.anchor = anchor
        self.policy = policy
    }
}

public final class SelectionCapturePipeline {
    private let triggerGate: SelectionTriggerGate
    private let eventGate: SelectionEventGate

    public init(
        triggerGate: SelectionTriggerGate = SelectionTriggerGate(),
        eventGate: SelectionEventGate
    ) {
        self.triggerGate = triggerGate
        self.eventGate = eventGate
    }

    public func reset() {
        triggerGate.reset()
        eventGate.reset()
    }

    public func observe(_ event: SelectionTriggerEvent) -> SelectionCaptureRequest? {
        guard let reason = triggerGate.observe(event) else { return nil }
        return SelectionCaptureRequest(
            anchor: event.location,
            policy: SelectionCapturePolicy.policy(for: reason)
        )
    }

    public func snapshot(
        for rawSelection: RawSelection,
        anchor: CGPoint,
        at date: Date
    ) -> SelectionSnapshot? {
        eventGate.snapshot(
            for: rawSelection.text,
            sourceBundleID: rawSelection.sourceBundleID,
            anchor: anchor,
            at: date
        )
    }
}
