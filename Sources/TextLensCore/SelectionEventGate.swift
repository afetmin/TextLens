import CoreGraphics
import Foundation

public struct SelectionSnapshot: Equatable, Sendable {
    public var text: String
    public var sourceBundleID: String?
    public var capturedAt: Date
    public var anchorPoint: CGPoint

    public init(text: String, sourceBundleID: String?, capturedAt: Date, anchorPoint: CGPoint) {
        self.text = text
        self.sourceBundleID = sourceBundleID
        self.capturedAt = capturedAt
        self.anchorPoint = anchorPoint
    }
}

public final class SelectionEventGate {
    private let debounceInterval: TimeInterval
    private let maximumTextLength: Int
    private var lastAcceptedText: String?
    private var lastAcceptedBundleID: String?
    private var lastAcceptedAt: Date?

    public init(debounceInterval: TimeInterval, maximumTextLength: Int) {
        self.debounceInterval = debounceInterval
        self.maximumTextLength = maximumTextLength
    }

    public func reset() {
        lastAcceptedText = nil
        lastAcceptedBundleID = nil
        lastAcceptedAt = nil
    }

    public func snapshot(
        for rawText: String?,
        sourceBundleID: String?,
        anchor: CGPoint,
        at date: Date
    ) -> SelectionSnapshot? {
        guard let text = rawText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        guard text.count <= maximumTextLength else {
            return nil
        }

        if text == lastAcceptedText,
           sourceBundleID == lastAcceptedBundleID,
           let lastAcceptedAt,
           date.timeIntervalSince(lastAcceptedAt) < debounceInterval {
            return nil
        }

        lastAcceptedText = text
        lastAcceptedBundleID = sourceBundleID
        lastAcceptedAt = date

        return SelectionSnapshot(
            text: text,
            sourceBundleID: sourceBundleID,
            capturedAt: date,
            anchorPoint: anchor
        )
    }
}
