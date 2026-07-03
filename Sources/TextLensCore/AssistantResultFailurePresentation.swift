public enum AssistantResultFailure: Equatable, Sendable {
    case missingAPIKey
    case providerFailure(message: String)
}

public enum AssistantResultFailureTone: Equatable, Sendable {
    case setup
    case warning
}

public struct AssistantResultFailurePresentation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var tone: AssistantResultFailureTone
    public var systemImageName: String
    public var shouldOfferSettings: Bool
    public var showsEmptyResultPlaceholder: Bool

    public static func make(
        for failure: AssistantResultFailure,
        action: SelectionAction
    ) -> AssistantResultFailurePresentation {
        switch failure {
        case .missingAPIKey:
            AssistantResultFailurePresentation(
                title: "需要配置 API Key",
                message: action == .translate ? "设置后即可继续翻译" : "设置后即可继续解释",
                tone: .setup,
                systemImageName: "key",
                shouldOfferSettings: true,
                showsEmptyResultPlaceholder: false
            )
        case .providerFailure(let message):
            AssistantResultFailurePresentation(
                title: action == .translate ? "翻译失败" : "解释失败",
                message: message,
                tone: .warning,
                systemImageName: "exclamationmark.triangle",
                shouldOfferSettings: false,
                showsEmptyResultPlaceholder: false
            )
        }
    }
}
