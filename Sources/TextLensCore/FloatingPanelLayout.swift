import CoreGraphics

public enum FloatingPanelPlacement: Equatable, Sendable {
    case aboveAnchor
    case belowAnchor
}

public struct FloatingPanelLayoutResult: Equatable, Sendable {
    public var frame: CGRect
    public var placement: FloatingPanelPlacement

    public init(frame: CGRect, placement: FloatingPanelPlacement) {
        self.frame = frame
        self.placement = placement
    }
}

public struct FloatingPanelLayoutRules: Equatable, Sendable {
    public var screenInset: CGFloat
    public var anchorGap: CGFloat
    public var horizontalOffset: CGFloat
    public var preferredPlacement: FloatingPanelPlacement

    public init(
        screenInset: CGFloat,
        anchorGap: CGFloat,
        horizontalOffset: CGFloat,
        preferredPlacement: FloatingPanelPlacement
    ) {
        self.screenInset = screenInset
        self.anchorGap = anchorGap
        self.horizontalOffset = horizontalOffset
        self.preferredPlacement = preferredPlacement
    }

    public func layout(
        preferredSize: CGSize,
        near anchor: CGPoint,
        in visibleFrame: CGRect
    ) -> FloatingPanelLayoutResult {
        let safeFrame = makeSafeFrame(from: visibleFrame)
        let width = min(max(preferredSize.width, 1), safeFrame.width)
        let preferredHeight = min(max(preferredSize.height, 1), safeFrame.height)
        let gap = max(anchorGap, 0)

        let aboveSpace = max(0, safeFrame.maxY - (anchor.y + gap))
        let belowSpace = max(0, (anchor.y - gap) - safeFrame.minY)
        let placement = choosePlacement(
            preferredHeight: preferredHeight,
            aboveSpace: aboveSpace,
            belowSpace: belowSpace
        )
        let availableHeight = max(1, placement == .aboveAnchor ? aboveSpace : belowSpace)
        let height = min(preferredHeight, availableHeight, safeFrame.height)

        let x = clamp(
            anchor.x + horizontalOffset,
            min: safeFrame.minX,
            max: safeFrame.maxX - width
        )
        let y: CGFloat
        switch placement {
        case .aboveAnchor:
            y = clamp(anchor.y + gap, min: safeFrame.minY, max: safeFrame.maxY - height)
        case .belowAnchor:
            y = clamp(anchor.y - gap - height, min: safeFrame.minY, max: safeFrame.maxY - height)
        }

        return FloatingPanelLayoutResult(
            frame: CGRect(x: x, y: y, width: width, height: height),
            placement: placement
        )
    }

    private func makeSafeFrame(from visibleFrame: CGRect) -> CGRect {
        let frame = visibleFrame.standardized
        let inset = max(screenInset, 0)
        let horizontalInset = min(inset, max(0, frame.width / 2 - 0.5))
        let verticalInset = min(inset, max(0, frame.height / 2 - 0.5))
        let insetFrame = frame.insetBy(dx: horizontalInset, dy: verticalInset)

        return CGRect(
            x: insetFrame.minX,
            y: insetFrame.minY,
            width: max(insetFrame.width, 1),
            height: max(insetFrame.height, 1)
        )
    }

    private func choosePlacement(
        preferredHeight: CGFloat,
        aboveSpace: CGFloat,
        belowSpace: CGFloat
    ) -> FloatingPanelPlacement {
        let preferredSpace = space(
            for: preferredPlacement,
            aboveSpace: aboveSpace,
            belowSpace: belowSpace
        )
        if preferredSpace >= preferredHeight {
            return preferredPlacement
        }

        let fallbackPlacement: FloatingPanelPlacement = preferredPlacement == .aboveAnchor ? .belowAnchor : .aboveAnchor
        let fallbackSpace = space(
            for: fallbackPlacement,
            aboveSpace: aboveSpace,
            belowSpace: belowSpace
        )
        if fallbackSpace >= preferredHeight {
            return fallbackPlacement
        }

        return aboveSpace >= belowSpace ? .aboveAnchor : .belowAnchor
    }

    private func space(
        for placement: FloatingPanelPlacement,
        aboveSpace: CGFloat,
        belowSpace: CGFloat
    ) -> CGFloat {
        switch placement {
        case .aboveAnchor:
            aboveSpace
        case .belowAnchor:
            belowSpace
        }
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), Swift.max(minimum, maximum))
    }
}
