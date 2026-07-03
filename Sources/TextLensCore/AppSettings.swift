import Foundation

public enum TranslationEngine: String, Codable, Equatable, CaseIterable, Sendable {
    case appleTranslation
    case openAICompatible
}

public enum ExplanationEngine: String, Codable, Equatable, CaseIterable, Sendable {
    case openAICompatible
}

public struct AppSettings: Codable, Equatable, Sendable {
    private static let currentSchemaVersion = 2

    public var selectionPopupEnabled: Bool
    public var targetLanguage: String
    public var translationEngine: TranslationEngine
    public var explanationEngine: ExplanationEngine
    public var providerConfig: AIProviderConfig

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case selectionPopupEnabled
        case targetLanguage
        case translationEngine
        case explanationEngine
        case providerConfig
    }

    public init(
        selectionPopupEnabled: Bool,
        targetLanguage: String,
        translationEngine: TranslationEngine,
        explanationEngine: ExplanationEngine,
        providerConfig: AIProviderConfig
    ) {
        self.selectionPopupEnabled = selectionPopupEnabled
        self.targetLanguage = targetLanguage
        self.translationEngine = translationEngine
        self.explanationEngine = explanationEngine
        self.providerConfig = providerConfig
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        selectionPopupEnabled = try container.decodeIfPresent(Bool.self, forKey: .selectionPopupEnabled) ?? Self.default.selectionPopupEnabled
        targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage) ?? Self.default.targetLanguage
        providerConfig = try container.decodeIfPresent(AIProviderConfig.self, forKey: .providerConfig) ?? Self.default.providerConfig

        let decodedTranslationEngine = try container.decodeIfPresent(TranslationEngine.self, forKey: .translationEngine)
        translationEngine = schemaVersion < Self.currentSchemaVersion
            ? .appleTranslation
            : decodedTranslationEngine ?? Self.default.translationEngine
        _ = try container.decodeIfPresent(String.self, forKey: .explanationEngine)
        explanationEngine = .openAICompatible
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(selectionPopupEnabled, forKey: .selectionPopupEnabled)
        try container.encode(targetLanguage, forKey: .targetLanguage)
        try container.encode(translationEngine, forKey: .translationEngine)
        try container.encode(explanationEngine, forKey: .explanationEngine)
        try container.encode(providerConfig, forKey: .providerConfig)
    }

    public static let `default` = AppSettings(
        selectionPopupEnabled: true,
        targetLanguage: "zh-Hans",
        translationEngine: .appleTranslation,
        explanationEngine: .openAICompatible,
        providerConfig: .default
    )
}
