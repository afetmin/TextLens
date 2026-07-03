public enum TranslationResultSource: Equatable, Sendable {
    case originalText
    case appleTranslation
    case openAICompatible
    case openAICompatibleAfterAppleFallback
}

public struct TranslationSourcePresentation: Equatable, Sendable {
    public var label: String
    public var accessibilityLabel: String
    public var helpText: String

    public static func make(for source: TranslationResultSource) -> TranslationSourcePresentation {
        switch source {
        case .originalText:
            TranslationSourcePresentation(
                label: "原文",
                accessibilityLabel: "源语言已是目标语言",
                helpText: "源语言已是目标语言，直接显示原文"
            )
        case .appleTranslation:
            TranslationSourcePresentation(
                label: "Apple",
                accessibilityLabel: "Apple 翻译",
                helpText: "使用 Apple 翻译"
            )
        case .openAICompatible:
            TranslationSourcePresentation(
                label: "大模型",
                accessibilityLabel: "大模型翻译",
                helpText: "使用大模型翻译"
            )
        case .openAICompatibleAfterAppleFallback:
            TranslationSourcePresentation(
                label: "大模型",
                accessibilityLabel: "Apple 翻译失败，已回退到大模型翻译",
                helpText: "Apple 翻译失败，已回退到大模型"
            )
        }
    }
}
