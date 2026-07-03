public enum SelectionAction: String, Codable, Equatable, Hashable, Sendable {
    case translate
    case explain

    public static let defaultTipActions: [SelectionAction] = [.translate, .explain]
}

public struct SelectionActionPlan: Equatable, Sendable {
    public var showsResultPanel: Bool
    public var loadsTranslation: Bool
    public var loadsExplanation: Bool

    public static func plan(for action: SelectionAction) -> SelectionActionPlan {
        switch action {
        case .translate:
            SelectionActionPlan(
                showsResultPanel: true,
                loadsTranslation: true,
                loadsExplanation: false
            )
        case .explain:
            SelectionActionPlan(
                showsResultPanel: true,
                loadsTranslation: false,
                loadsExplanation: true
            )
        }
    }
}
